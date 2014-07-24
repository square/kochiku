require 'spec_helper'
require 'partitioner'

describe BuildMailer do
  let(:build) { FactoryGirl.create(:build) }

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
    let(:build) { FactoryGirl.create(:main_project_build) }

    before do
      partitioner = instance_double('Partitioner::Base')
      allow(partitioner).to receive(:emails_for_commits_causing_failures).and_return({})
      allow(Partitioner).to receive(:for_build).and_return(partitioner)

      build_part = build.build_parts.create!(:paths => ["a", "b"], :kind => "cucumber", :queue => :ci)
      build_part.build_attempts.create!(:state => :failed, :builder => "test-builder")
    end

    context "on master as the main build for the project" do
      before do
        allow(GitBlame).to receive(:changes_since_last_green).and_return([{:hash => "sha", :author => "Joe", :date => "some day", :message => "always be shipping it"}])
        allow(GitBlame).to receive(:emails_since_last_green).and_return(["foo@example.com"])
      end

      it "sends the email" do
        expect(build.project).to be_main

        email = BuildMailer.build_break_email(build)

        expect(email.to).to eq(["foo@example.com"])
        expect(email.html_part.body).to include(build.project.name)
        expect(email.text_part.body).to include(build.project.name)
        expect(email.html_part.body).to include("http://")
        expect(email.text_part.body).to include("http://")
      end
    end

    context "on a branch" do
      let(:build) { FactoryGirl.create(:build, :branch => "branch-of-master") }

      before do
        allow(GitBlame).to receive(:changes_in_branch).and_return([{:hash => "sha", :author => "Joe", :date => "some day", :message => "always be shipping it"}])
        allow(GitBlame).to receive(:emails_in_branch).and_return(["foo@example.com"])
      end

      it "sends the email" do
        email = BuildMailer.build_break_email(build)

        expect(email.to).to eq(["foo@example.com"])
        expect(email.html_part.body).to include(build.project.name)
        expect(email.text_part.body).to include(build.project.name)
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
        expect(email.html_part.body).to include(build.project.name)
        expect(email.text_part.body).to include(build.project.name)
        expect(email.html_part.body).to include("http://")
        expect(email.text_part.body).to include("http://")
      end
    end
  end

  describe '#build_success_email' do
    let(:build) { FactoryGirl.create(:build, :branch => "branch-of-master") }

    before do
      allow(GitBlame).to receive(:changes_in_branch).and_return([{:hash => "sha", :author => "Joe", :date => "some day", :message => "always be shipping it"}])
      allow(GitBlame).to receive(:last_email_in_branch).and_return(["foo@example.com"])
    end

    it "sends an email" do
      build_part = build.build_parts.create!(:paths => ["a", "b"], :kind => "cucumber", :queue => :ci)
      build_part.build_attempts.create!(:state => :passed, :builder => "test-builder")

      email = BuildMailer.build_success_email(build)

      expect(email.to).to eq(["foo@example.com"])

      expect(email.html_part.body).to include(build_part.project.name)
      expect(email.text_part.body).to include(build_part.project.name)
      expect(email.html_part.body).to include("http://")
      expect(email.text_part.body).to include("http://")
    end
  end
end
