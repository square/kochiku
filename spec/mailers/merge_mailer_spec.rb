require "spec_helper"

describe MergeMailer do
  describe "merge_successful" do
    it "sends the email" do
      email = MergeMailer.merge_successful(FactoryBot.create(:build), to_40('w'), ["foo@example.com"], 'deploy log')
      expect(email.to).to include("foo@example.com")
    end
  end

  describe "merge_failed" do
    it "sends the email" do
      email = MergeMailer.merge_failed(FactoryBot.create(:build), ["foo@example.com"], 'deploy log')
      expect(email.to).to include("foo@example.com")
    end
  end
end
