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

    it "should not send a failure email if the project has never had a successful build" do
      BuildPartMailer.should_not_receive(:build_break_email)
      build_attempt.build_part.build_instance.previous_successful_build.should be_nil
      subject
      ActionMailer::Base.deliveries.should be_empty
    end

    context "for a build that has had a successful build" do
      let(:build) { FactoryGirl.create(:build, :state => :succeeded, :project => project); FactoryGirl.create(:build, :state => :runnable, :project => project) }

      it "should send a fail email when the build part fails" do
        BuildPartMailer.should_receive(:build_break_email).and_return(OpenStruct.new(:deliver => nil))
        build_attempt.assign_attributes(:state => :failed)
        subject
      end

      context "for a build of a project not on master" do
        let(:project) { FactoryGirl.create(:project, :branch => "other-branch")}

        it "should not send a failure email" do
          BuildPartMailer.should_not_receive(:build_break_email)
          build_attempt.assign_attributes(:state => :failed)
          subject
        end
      end
    end
  end
end
