require 'spec_helper'

describe Build do
  let(:project) { projects(:big_rails_app) }
  let(:build) { Build.create!(:project => project, :ref => "deadbeef", :state => :partitioning, :queue => :ci) }
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
    it "returns the difference between the build creation time and the last finished time" do
      build.partition(parts)
      build.elapsed_time.should be_nil
      last_attempt = BuildAttempt.find(build.build_attempts.last.id)
      last_attempt.update_attributes(:finished_at => build.created_at + 10.minutes)
      build.elapsed_time.should be_within(1.second).of(10.minutes)
    end
  end
end
