require "spec_helper"

describe BuildPartMailer do
  let(:build) { FactoryGirl.create(:build, :queue => :developer) }

  describe "#time_out_email" do
    it "sends the email" do
      build_part = build.build_parts.create!(:paths => ["a", "b"], :kind => "cucumber")
      build_part.build_attempts.build(:state => :errored, :builder => "test-builder")

      email = BuildPartMailer.time_out_email(build_part)
      email.to.should include("build-and-release+timeouts@squareup.com")
      email.body.should include("test-builder")
      email.body.should include("http://")
    end
  end

  describe "#build_break_email" do
    before do
      GitBlame.stub(:git_changes_since_last_green).and_return([{:hash => "sha", :author => "Joe", :date => "some day", :message => "always be shipping it"}])
    end

    it "sends the email" do
      build_part = build.build_parts.create!(:paths => ["a", "b"], :kind => "cucumber")
      build_attempt = build_part.build_attempts.create!(:state => :failed, :builder => "test-builder")
      emails = ["foo@example.com"]

      email = BuildPartMailer.build_break_email(emails, build)

      email.to.should == ["foo@example.com"]

      email.bcc.should include("cheister@squareup.com")
      email.html_part.body.should include(build_part.project.name)
      email.text_part.body.should include(build_part.project.name)
      email.html_part.body.should include("http://")
      email.text_part.body.should include("http://")
    end
  end
end
