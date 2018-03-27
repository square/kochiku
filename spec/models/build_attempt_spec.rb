require 'spec_helper'

describe BuildAttempt do
  it "requires a valid state" do
    build_attempt = BuildAttempt.new(:state => "asasdfsdf")
    expect(build_attempt).not_to be_valid
    expect(build_attempt).to have(1).error_on(:state)
    build_attempt.state = 'runnable'
    expect(build_attempt).to be_valid
  end

  describe "finish!" do
    let(:build) { FactoryGirl.create(:build, :state => 'runnable', :merge_on_success => true) }
    let(:build_part) { FactoryGirl.create(:build_part, :build_instance => build, retry_count: 2) }
    let!(:build_attempt) { FactoryGirl.create(:build_attempt, :state => 'running', :build_part => build_part) }

    context "build auto-retries" do
      it "requests a rebuild if should_reattempt? is true" do
        allow(build_part).to receive(:should_reattempt?).and_return(true)
        expect(build_part).to receive(:rebuild!)
        build_attempt.finish!('failed')
      end

      it "does not request a rebuild if should_reattempt? is false" do
        allow(build_part).to receive(:should_reattempt?).and_return(false)
        expect(build_part).to_not receive(:rebuild!)
        build_attempt.finish!('failed')
      end
    end

    it "calls update_state_from_parts!" do
      expect(build).to receive(:update_state_from_parts!).at_least(:once)
      build_attempt.finish!('passed')
    end

    it "sends an email for an errored build" do
      expect(BuildMailer).to receive(:error_email).and_return(OpenStruct.new(:deliver => nil))
      allow(build_attempt).to receive(:should_reattempt?).and_return(false)
      build_attempt.finish!('errored')
    end
  end
end
