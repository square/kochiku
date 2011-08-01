require 'spec_helper'

describe Build do
  let(:project) { FactoryGirl.create(:big_rails_project) }
  let(:build) { FactoryGirl.create(:build, :project => project) }
  let(:parts) { [{'type' => 'cucumber', 'files' => ['a', 'b']}, {'type' => 'rspec', 'files' => ['c', 'd']}] }

  describe "validations" do
    it "requires a ref to be set" do
      build.ref = nil
      build.should_not be_valid
      build.should have(1).errors_on(:ref)
    end
  end

  describe "#partition" do
    it "should create a BuildPart for each path" do
      build.partition(parts)
      build.build_parts.map(&:kind).should =~ ['cucumber', 'rspec']
      build.build_parts.find_by_kind('cucumber').paths.should =~ ['a', 'b']
    end

    it "should change state to runnable" do
      build.partition(parts)
      build.state.should == :runnable
    end

    it "should create build attempts for each build part" do
      build.partition(parts)
      build.build_parts.all {|bp| bp.build_attempts.should have(1).item }
    end

    it "should enqueue build part jobs" do
      BuildAttemptJob.should_receive(:enqueue_on).twice
      build.partition(parts)
    end

    it "rolls back any changes to the database if an error occurs" do
      build.stub(:build_parts).and_raise(ActiveRecord::Rollback)

      expect { build.partition(parts) }.to_not change { build.reload.state }
    end
  end

  describe "#completed?" do
    Build::TERMINAL_STATES.each do |state|
      it "should be true for #{state}" do
        build.state = state
        build.should be_completed
      end
    end

    (Build::STATES - Build::TERMINAL_STATES).each do |state|
      it "should be false for #{state}" do
        build.state = state
        build.should_not be_completed
      end
    end
  end

  describe "#update_state_from_parts!" do
    let(:parts) { [{'type' => 'cucumber', 'files' => ['a']}, {'type' => 'rspec', 'files' => ['b']}] }
    before do
      build.partition(parts)
      build.state.should == :runnable
    end

    it "should set a build state to running if it is successful so far, but still incomplete" do
      build.build_parts[0].last_attempt.finish!(:passed)
      build.update_state_from_parts!

      build.state.should == :running
    end

    it "should set build state to error if any of its parts errored" do
      build.build_parts[0].last_attempt.finish!(:error)
      build.build_parts[1].last_attempt.finish!(:passed)
      build.update_state_from_parts!

      build.state.should == :error
    end

    it "should set build state to succeeded all of its parts passed" do
      build.build_parts[0].last_attempt.finish!(:passed)
      build.build_parts[1].last_attempt.finish!(:passed)
      build.update_state_from_parts!

      build.state.should == :succeeded
    end

    it "should set a build state to doomed if it has a failed part but is still has more parts to process" do
      build.build_parts[0].last_attempt.finish!(:failed)
      build.update_state_from_parts!
      build.state.should == :doomed
    end

    it "should change a doomed build to failed once it is complete" do
      build.build_parts[0].last_attempt.finish!(:failed)
      build.update_state_from_parts!
      build.state.should == :doomed

      build.build_parts[1].last_attempt.finish!(:passed)
      build.update_state_from_parts!
      build.state.should == :failed
    end

    it "should ignore the old build_attempts" do
      build.build_parts[0].last_attempt.finish!(:passed)
      build.build_parts[1].last_attempt.finish!(:error)
      build.build_parts[1].build_attempts.create!(:state => :passed)
      build.update_state_from_parts!

      build.state.should == :succeeded
    end
  end

  describe "#elapsed_time" do
    it "returns the difference between the build creation time and the last finished time" do
      build.partition(parts)
      build.elapsed_time.should be_nil
      last_attempt = BuildAttempt.find(build.build_attempts.last.id)
      last_attempt.update_attributes(:finished_at => build.created_at + 10.minutes)
      build.elapsed_time.should be_within(1.second).of(10.minutes)
    end
  end
end
