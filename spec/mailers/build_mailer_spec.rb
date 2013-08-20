require "spec_helper"

describe BuildMailer do
  let(:build) { FactoryGirl.create(:build, :queue => :developer) }

  describe "#error_email" do
    before do
      Settings.stub(:sender_email_address).and_return('kochiku@example.com')
    end

    it "sends the email" do
      build_attempt = FactoryGirl.build(:build_attempt, :state => :errored, :builder => "test-builder")

      email = BuildMailer.error_email(build_attempt, "error text")

      email.to.should include(BuildMailer::NOTIFICATIONS_EMAIL)

      expect(email.from).to eq(['kochiku@example.com'])

      email.html_part.body.should include("test-builder")
      email.text_part.body.should include("test-builder")
      email.html_part.body.should include("http://")
      email.text_part.body.should include("http://")
      email.html_part.body.should include("error text")
      email.text_part.body.should include("error text")
    end
  end

  describe "#build_break_email" do
    context "on master as the main build for the project" do
      let(:repository) { FactoryGirl.create(:repository) }
      let(:project) { FactoryGirl.create(:project, :name => repository.repository_name)}
      let(:build) { FactoryGirl.create(:build, :queue => :developer, :project => project, :branch => "master") }

      before do
        GitBlame.stub(:changes_since_last_green).and_return([{:hash => "sha", :author => "Joe", :date => "some day", :message => "always be shipping it"}])
        GitBlame.stub(:emails_since_last_green).and_return(["foo@example.com"])
      end

      it "sends the email" do
        build.project.should be_main

        build_part = build.build_parts.create!(:paths => ["a", "b"], :kind => "cucumber")
        build_part.build_attempts.create!(:state => :failed, :builder => "test-builder")

        email = BuildMailer.build_break_email(build)

        email.to.should == ["foo@example.com"]

        email.bcc.should include(BuildMailer::NOTIFICATIONS_EMAIL)
        email.html_part.body.should include(build_part.project.name)
        email.text_part.body.should include(build_part.project.name)
        email.html_part.body.should include("http://")
        email.text_part.body.should include("http://")
      end
    end

    context "on a branch" do
      let(:build) { FactoryGirl.create(:build, :queue => :developer, :branch => "branch-of-master") }

      before do
        GitBlame.stub(:changes_in_branch).and_return([{:hash => "sha", :author => "Joe", :date => "some day", :message => "always be shipping it"}])
        GitBlame.stub(:emails_in_branch).and_return(["foo@example.com"])
      end

      it "sends the email" do
        build_part = build.build_parts.create!(:paths => ["a", "b"], :kind => "cucumber")
        build_part.build_attempts.create!(:state => :failed, :builder => "test-builder")

        email = BuildMailer.build_break_email(build)

        email.to.should == ["foo@example.com"]

        email.bcc.should include(BuildMailer::NOTIFICATIONS_EMAIL)
        email.html_part.body.should include(build_part.project.name)
        email.text_part.body.should include(build_part.project.name)
        email.html_part.body.should include("http://")
        email.text_part.body.should include("http://")
      end
    end
  end
end
