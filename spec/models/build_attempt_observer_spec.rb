require 'spec_helper'

describe BuildAttemptObserver do
  describe "after_save" do
    let(:build_part) { FactoryGirl.create(:build_part) }
    let(:observer) { BuildAttemptObserver.instance }
    subject { observer.after_save(build_attempt) }

    context "for a timed out build" do
      let(:build_attempt) { FactoryGirl.build(:build_attempt, state: :failed, started_at: 41.minutes.ago, :build_part => build_part) }

      it "sends email" do
        BuildPartTimeOutMailer.should_receive :time_out_email

        subject
      end
    end

    context "for a non timed out build" do
      let(:build_attempt) { FactoryGirl.build(:build_attempt,
                                              state: :failed,
                                              started_at: 10.minutes.ago,
                                              :build_part => build_part) }

      it "does not send mail" do
        BuildPartTimeOutMailer.should_not_receive :time_out_email

        subject
      end
    end
  end
end
