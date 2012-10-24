require "spec_helper"

describe AutoMergeMailer do
  describe "merge_successful" do
    it "sends the email" do
      email = AutoMergeMailer.merge_successful('foo@example.com', 'deploy log', FactoryGirl.create(:build))
      email.to.should include("foo@example.com")
    end
  end

  describe "merge_failed" do
    it "sends the email" do
      email = AutoMergeMailer.merge_failed('foo@example.com', 'deploy log', FactoryGirl.create(:build))
      email.to.should include("foo@example.com")
    end
  end
end
