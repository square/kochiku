require 'spec_helper'

describe BuildAttempt do
  it "requires a valid state" do
    build_attempt = BuildAttempt.new(:state => "asasdfsdf")
    build_attempt.should_not be_valid
    build_attempt.should have(1).errors_on(:state)
    build_attempt.state = :runnable
    build_attempt.should be_valid
  end

  describe "finish!" do
    let(:repository) { FactoryGirl.create(:repository, :timeout => 20) }
    let(:project) { FactoryGirl.create(:project, :branch => "master", :repository => repository) }
    let(:build) { FactoryGirl.create(:build, :state => :runnable, :project => project, :auto_merge => true) }
    #let(:build) { FactoryGirl.create(:build, :auto_merge => true) }
    let(:build_part) { FactoryGirl.create(:build_part, :build_instance => build, :kind => "cucumber") }
    let!(:build_attempt) { FactoryGirl.create(:build_attempt, :state => :running, :build_part => build_part) }

    context "build auto-retries" do
      [:failed, :errored].each do |state|
        it "reattempts an automerge cuke that #{state}" do
          build_part.should_receive(:rebuild!)
          build_attempt.finish!(state)
        end

        context "when there are already 3 failures" do
          before do
            3.times do
              FactoryGirl.create(:build_attempt, :state => :errored, :build_part => build_part)
            end
          end

          it "does not try again when it #{state}" do
            build_part.should_not_receive(:rebuild!)
            build_attempt.finish!(state)
          end
        end

        context "specs" do
          let(:build_part) { FactoryGirl.create(:build_part, :build_instance => build, :kind => "spec") }
          it "does not attempt to re-run specs when it #{state}" do
            build_part.should_not_receive(:rebuild!)
            build_attempt.finish!(state)
          end
        end

        context "non-automerged builds" do
          let(:build) { FactoryGirl.create(:build, :auto_merge => false, :queue => "developer") }
          it "does not attempt to re-run when it #{state}" do
            build_part.should_not_receive(:rebuild!)
            build_attempt.finish!(state)
          end
        end

        context "non-automerged ci builds" do
          let(:build) { FactoryGirl.create(:build, :auto_merge => false, :queue => "ci") }
          it "reattempts to re-run when it #{state}" do
            build_part.should_receive(:rebuild!)
            build_attempt.finish!(state)
          end
        end
      end

      [:runnable, :running, :passed, :aborted].each do |state|
        it "does not reattempt an automerge cuke that #{state}" do
          build_part.should_not_receive(:rebuild!)
          build_attempt.finish!(state)
        end
      end

      context "for a maven build of sake/rpc" do
        let(:build_part) { FactoryGirl.create(:build_part, :build_instance => build, :kind => "maven", :paths => ["sake/rpc"]) }
        it "should rebuild" do
          build_part.should_receive(:rebuild!)
          build_attempt.finish!(:failed)
        end
      end
    end

    it "calls update_state_from_parts!" do
      build.should_receive(:update_state_from_parts!).at_least(:once)
      build_attempt.finish!(:passed)
    end

    it "sends an email for an errored build" do
      BuildMailer.should_receive(:error_email).and_return(OpenStruct.new(:deliver => nil))
      build_attempt.stub(:should_reattempt?).and_return(false)
      build_attempt.finish!(:errored)
    end
  end
end
