require "spec_helper"

describe AutoMergeMailer do
  before do
    GitBlame.stub(:emails_since_last_green).and_return(["foo@example.com"])
  end

  describe "merge_successful" do
    it "sends the email" do
      email = AutoMergeMailer.merge_successful(FactoryGirl.create(:build), 'deploy log')
      email.to.should include("foo@example.com")
    end
  end

  describe "merge_failed" do
    it "sends the email" do
      email = AutoMergeMailer.merge_failed(FactoryGirl.create(:build), 'deploy log')
      email.to.should include("foo@example.com")
    end
  end
end
