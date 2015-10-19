require 'spec_helper'
require 'partitioner'

describe BuildMailer do

  describe "#error_email" do
    before do
      allow(Settings).to receive(:sender_email_address).and_return('kochiku@example.com')
      allow(Settings).to receive(:kochiku_notifications_email_address).and_return('notify@example.com')
    end

    it "sends the email" do
      build_attempt = FactoryGirl.build(:build_attempt, :state => :errored, :builder => "test-builder")

      email = BuildMailer.error_email(build_attempt, "error text")

      expect(email.to).to include('notify@example.com')

      expect(email.from).to eq(['kochiku@example.com'])

      expect(email.html_part.body).to include("test-builder")
      expect(email.text_part.body).to include("test-builder")
      expect(email.html_part.body).to include("http://")
      expect(email.text_part.body).to include("http://")
      expect(email.html_part.body).to include("error text")
      expect(email.text_part.body).to include("error text")
    end
  end

  describe "#build_break_email" do
    let(:repository) { FactoryGirl.create(:repository) }
    let(:branch) { FactoryGirl.create(:branch, repository: repository, name: 'funyuns') }
    let(:build) { FactoryGirl.create(:build, branch_record: branch) }

    before do
      partitioner = instance_double('Partitioner::Base')
      allow(partitioner).to receive(:emails_for_commits_causing_failures).and_return({})
      allow(Partitioner).to receive(:for_build).and_return(partitioner)

      build_part = build.build_parts.create!(:paths => ["a", "b"], :kind => "cucumber", :queue => :ci)
      @build_attempt = build_part.build_attempts.create!(:state => :failed, :builder => "test-builder")
      FactoryGirl.create(:stdout_build_artifact, build_attempt: @build_attempt)
    end

    context "on a convergence branch" do
      before do
        branch.update_attribute(:convergence, true)

        allow(GitBlame).to receive(:changes_since_last_green).and_return([{:hash => "sha", :author => "Joe", :date => "some day", :message => "always be shipping it"}])
        allow(GitBlame).to receive(:emails_since_last_green).and_return(["foo@example.com"])
      end

      it "sends the email" do
        expect(build.branch_record.convergence?).to be(true)

        email = BuildMailer.build_break_email(build)

        expect(email.to).to eq(["foo@example.com"])
        expect(email.html_part.body).to include(build.branch_record.name)
        expect(email.text_part.body).to include(build.branch_record.name)
        expect(email.html_part.body).to include("http://")
        expect(email.text_part.body).to include("http://")
      end
    end

    context "on a non-convergence branch" do
      before do
        expect(build.branch_record.convergence?).to be(false)

        allow(GitBlame).to receive(:changes_in_branch).and_return([{:hash => "sha", :author => "Joe", :date => "some day", :message => "always be shipping it"}])
        allow(GitBlame).to receive(:emails_in_branch).and_return(["foo@example.com"])
      end

      it "sends the email" do
        email = BuildMailer.build_break_email(build)

        expect(email.to).to eq(["foo@example.com"])
        expect(email.html_part.body).to include(build.branch_record.name)
        expect(email.text_part.body).to include(build.branch_record.name)
        expect(email.html_part.body).to include("http://")
        expect(email.text_part.body).to include("http://")
      end
    end

    context "with emails from a partitioner" do
      before do
        partitioner = instance_double('Partitioner::Base')
        allow(partitioner).to receive(:emails_for_commits_causing_failures).and_return({'foo@example.com' => ['sha']})
        allow(Partitioner).to receive(:for_build).and_return(partitioner)
        allow(GitBlame).to receive(:changes_since_last_green).and_return([{:hash => "sha", :author => "Foo", :date => "some day", :message => "does this work? LOL"}])
      end

      it "uses those emails" do
        email = BuildMailer.build_break_email(build)

        expect(email.to).to eq(["foo@example.com"])
        expect(email.html_part.body).to include(build.branch_record.name)
        expect(email.text_part.body).to include(build.branch_record.name)
        expect(email.html_part.body).to include("http://")
        expect(email.text_part.body).to include("http://")
        expect(email.html_part.body).to_not include("pull-requests/")
      end

      context "when the build is tied to an open pull request on Stash" do
        before do
          allow(build.repository.remote_server).to receive(:class).and_return(RemoteServer::Stash)
          allow(build.repository.remote_server).to receive(:get_pr_id_and_version).and_return(3, 4)
        end

        it "includes link to PR" do
          build_part = build.build_parts.create!(:paths => ["a", "b"], :kind => "cucumber", :queue => :ci)
          build_part.build_attempts.create!(:state => :passed, :builder => "test-builder")

          email = BuildMailer.build_break_email(build)
          expect(email.html_part.body).to include("pull-requests/3/overview")
        end
      end
    end

    describe 'failed build part information' do
      context 'stdout log file has been uploaded' do
        it 'should link to the log file' do
          stdout_artifact = @build_attempt.build_artifacts.stdout_log.first
          email = BuildMailer.build_break_email(build)
          expect(email.text_part.body).to include(build_artifact_url(stdout_artifact))
          expect(email.html_part.body).to include(build_artifact_url(stdout_artifact))
        end
      end

      context 'stdout log file has not been uploaded yet' do
        before do
          @build_attempt.build_artifacts.delete_all
        end

        it 'should not link to the log file' do
          email = BuildMailer.build_break_email(build)
          expect(email.text_part.body).to_not include("/build_artifacts/")
          expect(email.html_part.body).to_not include("/build_artifacts/")
        end
      end
    end
  end

  describe '#build_success_email' do
    let(:repository) { FactoryGirl.create(:repository) }
    let(:branch) { FactoryGirl.create(:branch, repository: repository, name: 'funyuns') }
    let(:build) { FactoryGirl.create(:build, branch_record: branch) }

    before do
      allow(GitBlame).to receive(:changes_in_branch).and_return([{hash: "sha", author: "Joe", date: "some day", message: "always be shipping it"}])
      allow(GitBlame).to receive(:last_email_in_branch).and_return(["foo@example.com"])

      build_part = build.build_parts.create!(paths: ["a", "b"], kind: "cucumber", queue: :ci)
      build_part.build_attempts.create!(state: :passed, builder: "test-builder")
    end

    it "sends an email" do
      email = BuildMailer.build_success_email(build)

      expect(email.to).to eq(["foo@example.com"])

      expect(email.html_part.body).to include(repository.name)
      expect(email.text_part.body).to include(repository.name)
      expect(email.html_part.body).to include("http://")
      expect(email.text_part.body).to include("http://")
    end

    context "stash repository" do
      let(:repository) { FactoryGirl.create(:stash_repository) }
      let(:branch) { FactoryGirl.create(:branch, repository: repository, name: 'funyuns') }
      let(:build) { FactoryGirl.create(:build, branch_record: branch) }

      context "build has an open pull request" do
        before do
          allow(build.repository.remote_server).to receive(:class).and_return(RemoteServer::Stash)
          allow(build.repository.remote_server).to receive(:get_pr_id_and_version).and_return(3, 4)
        end

        it "includes link to PR" do
          email = BuildMailer.build_success_email(build)
          expect(email.html_part.body).to include("pull-requests/3/overview")
        end
      end

      context "build does not have a pull request" do
        before do
          allow(build.repository.remote_server).to receive(:class).and_return(RemoteServer::Stash)
          allow(build.repository.remote_server).to receive(:get_pr_id_and_version).and_raise(RemoteServer::StashAPIError)
        end

        it "does not link to a pull request" do
          email = BuildMailer.build_success_email(build)
          expect(email.html_part.body).to_not include("pull-requests/")
        end
      end
    end
  end
end
