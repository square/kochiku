require 'spec_helper'

describe BuildAttemptObserver do
  describe "after_save" do
    let(:project) { FactoryGirl.create(:project, :branch => "master")}
    let(:build) { FactoryGirl.create(:build, :state => :runnable, :project => project) }
    let(:build_part) { FactoryGirl.create(:build_part, :build_instance => build) }
    let(:build_attempt) { FactoryGirl.create(:build_attempt, :build_part => build_part) }
    let(:observer) { BuildAttemptObserver.instance }

    subject { observer.after_save(build_attempt) }

    it "sends email for a timed out build" do
      BuildPartMailer.should_receive(:time_out_email).and_return(OpenStruct.new(:deliver => nil))
      build_attempt.assign_attributes(:state => :failed, :started_at => 41.minutes.ago)
      subject
    end

    it "does not send a timeout mail for a failed non timed out build" do
      BuildPartMailer.should_not_receive(:time_out_email)
      build_attempt.assign_attributes(:state => :failed, :started_at => 10.minutes.ago)
      subject
    end
  end
end
