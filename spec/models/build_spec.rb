require 'spec_helper'

describe Build do
  let(:project) { projects(:big_rails_app) }
  let(:build) { Build.create(:project => project, :sha => "deadbeef", :state => :partitioning, :queue => :q) }
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
end
