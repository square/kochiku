require "spec_helper"

describe BuildPartTimeOutMailer do
  let(:build) { FactoryGirl.create(:build, :queue => :ci) }

  it "sends the email" do
    build_part = build.build_parts.create!(:paths => ["a", "b"], :kind => "cucumber")
    build_part.build_attempts.build(:state => :errored, :builder => "test-builder")

    email = BuildPartTimeOutMailer.time_out_email(build_part)
    ActionMailer::Base.deliveries.should_not be_empty
    email.to.should include("build-and-release+timeouts@squareup.com")
    email.body.should include("test-builder")
    email.body.should include("http://")
  end
end