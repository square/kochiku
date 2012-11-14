require "spec_helper"

describe AutoMergeMailer do
  describe "merge_successful" do
    it "sends the email" do
      email = AutoMergeMailer.merge_successful(FactoryGirl.create(:build), ["foo@example.com"], 'deploy log')
      email.to.should include("foo@example.com")
    end
  end

  describe "merge_failed" do
    it "sends the email" do
      email = AutoMergeMailer.merge_failed(FactoryGirl.create(:build), ["foo@example.com"], 'deploy log')
      email.to.should include("foo@example.com")
    end
  end
end
