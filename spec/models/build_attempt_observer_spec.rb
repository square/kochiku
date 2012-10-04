require 'spec_helper'

describe BuildAttemptObserver do
  describe "after_save" do
    let(:observer) { BuildAttemptObserver.instance }
    subject { observer.after_save(build_attempt) }

    context "for a timed out build" do
      let(:build_attempt) { FactoryGirl.build(:build_attempt, state: :failed, started_at: 41.minutes.ago) }

      it "sends email" do
        BuildPartTimeOutMailer.should_receive :send

        subject
      end
    end

    context "for a non timed out build" do
      let(:build_attempt) { FactoryGirl.build(:build_attempt,
                                              state: :failed,
                                              started_at: 10.minutes.ago) }

      it "does not send mail" do
        BuildPartTimeOutMailer.should_not_receive :end

        subject
      end
    end
  end
end
