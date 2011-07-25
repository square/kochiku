require 'spec_helper'

describe Build do
  let(:project) { FactoryGirl.create(:big_rails_project) }
  let(:build) { FactoryGirl.create(:build, :project => project) }
  let(:parts) { [{'type' => 'cucumber', 'files' => ['a', 'b']}, {'type' => 'rspec', 'files' => ['c', 'd']}] }

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
    
    it "should enqueue build part jobs" do
      BuildPartJob.should_receive(:enqueue_on).twice
      build.partition(parts)
    end

    it "rolls back any changes to the database if an error occurs" do
      build.stub(:build_parts).and_raise(ActiveRecord::Rollback)

      expect { build.partition(parts) }.to_not change { build.reload.state }
    end

  end

  it "requires a ref to be set" do
    build.ref = nil
    build.should_not be_valid
    build.should have(1).errors_on(:ref)
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

  describe "#elapsed_time" do
    it "returns the greatest elapsed time of all the build parts" do
      build.partition(parts)
      build.elapsed_time.should be_nil
      last_attempt = BuildAttempt.find(build.build_attempts.last.id)
      another_attempt = BuildAttempt.find(build.build_attempts.first.id)
      last_attempt.update_attributes(:started_at => 10.minutes.ago, :finished_at => Time.current)
      another_attempt.update_attributes(:started_at => 8.minutes.ago, :finished_at => Time.current)
      build.elapsed_time.should == 10.minutes
    end
  end
end
