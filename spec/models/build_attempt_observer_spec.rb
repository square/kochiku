require 'spec_helper'

describe BuildAttemptObserver do
  describe "after_save" do
    let(:repository) { FactoryGirl.create(:repository, :timeout => 20) }
    let(:project) { FactoryGirl.create(:project, :branch => "master", :repository => repository) }
    let(:build) { FactoryGirl.create(:build, :state => :runnable, :project => project) }
    let(:build_part) { FactoryGirl.create(:build_part, :build_instance => build) }
    let(:build_attempt) { FactoryGirl.create(:build_attempt, :build_part => build_part) }
    let(:observer) { BuildAttemptObserver.instance }

    subject { observer.after_save(build_attempt) }

    it "calls update_state_from_parts!" do
      build.should_receive(:update_state_from_parts!).at_least(:once)
      subject
    end

    it "sends email for a timed out build" do
      BuildMailer.should_receive(:time_out_email).and_return(OpenStruct.new(:deliver => nil))
      build_attempt.assign_attributes(:state => :failed, :started_at => 21.minutes.ago)
      subject
    end

    it "does not send a timeout mail for a failed non timed out build" do
      BuildMailer.should_not_receive(:time_out_email)
      build_attempt.assign_attributes(:state => :failed, :started_at => 10.minutes.ago)
      subject
    end

    it "sends an email for an errored build" do
      BuildMailer.should_receive(:error_email).and_return(OpenStruct.new(:deliver => nil))
      build_attempt.assign_attributes(:state => :errored)
      subject
    end
  end
end
