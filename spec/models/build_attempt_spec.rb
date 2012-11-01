require 'spec_helper'

describe BuildAttempt do
  it "requires a valid state" do
    ba = BuildAttempt.new(:state => "asasdfsdf")
    ba.should_not be_valid
    ba.should have(1).errors_on(:state)
    ba.state = :runnable
    ba.should be_valid
  end

  context "build auto-retries" do
    let(:build) { FactoryGirl.create(:build, :auto_merge => true) }
    let(:build_part) { FactoryGirl.create(:build_part, :build_instance => build, :kind => "cucumber") }
    let!(:build_attempt) { FactoryGirl.create(:build_attempt, :state => :running, :build_part => build_part) }

    [:failed, :errored].each do |state|
      it "reattempts an automerge cuke that #{state}" do
        build_part.should_receive(:rebuild!)
        build_attempt.update_attributes(:state => state)
      end

      context "when there are already 3 failures" do
        before do
          3.times do
            FactoryGirl.create(:build_attempt, :state => :errored, :build_part => build_part)
          end
        end

        it "does not try again when it #{state}" do
          build_part.should_not_receive(:rebuild!)
          build_attempt.update_attributes(:state => state)
        end
      end

      context "specs" do
        let(:build_part) { FactoryGirl.create(:build_part, :build_instance => build, :kind => "spec") }
        it "does not attempt to re-run specs when it #{state}" do
          build_part.should_not_receive(:rebuild!)
          build_attempt.update_attributes(:state => state)
        end
      end

      context "non-automerged builds" do
        let(:build) { FactoryGirl.create(:build, :auto_merge => false, :queue => "developer") }
        it "does not attempt to re-run when it #{state}" do
          build_part.should_not_receive(:rebuild!)
          build_attempt.update_attributes(:state => state)
        end
      end

      context "non-automerged ci builds" do
        let(:build) { FactoryGirl.create(:build, :auto_merge => false, :queue => "ci") }
        it "reattempts to re-run when it #{state}" do
          build_part.should_receive(:rebuild!)
          build_attempt.update_attributes(:state => state)
        end
      end
    end

    [:runnable, :running, :passed, :aborted].each do |state|
      it "does not reattempt an automerge cuke that #{state}" do
        build_part.should_not_receive(:rebuild!)
        build_attempt.update_attributes(:state => state)
      end
    end

    context "for a maven build of sake/rpc" do
      let(:build_part) { FactoryGirl.create(:build_part, :build_instance => build, :kind => "maven", :paths => ["sake/rpc"]) }
      it "should rebuild" do
        build_part.should_receive(:rebuild!)
        build_attempt.update_attributes(:state => :failed)
      end
    end
  end
end
