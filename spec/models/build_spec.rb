require 'spec_helper'

describe Build do
  let(:build) { Build.create(:sha => "deadbeef", :state => :partitioning, :queue => :q) }
  let(:parts) { [{'type' => 'cucumber', 'files' => ['a', 'b']},{'type' => 'rspec', 'files' => ['c', 'd']}]}

  describe "#partition" do
    it "should create a BuildPart for each path" do
      build.partition(parts)
      build.build_parts.map(&:kind).should =~ ['cucumber', 'rspec']
      build.build_parts.find_by_kind('cucumber').paths.should =~ ['a', 'b']
    end
  end

  describe "#enqueue" do
    before do
      build.partition(parts)
    end

    it "should change state to runnable" do
      build.enqueue
      build.state.should == :runnable
    end

    it "should enqueue build part jobs" do
      BuildPartJob.should_receive(:enqueue_in).with(build.queue, build.build_parts.first.id)
      BuildPartJob.should_receive(:enqueue_in).with(build.queue, build.build_parts.last.id)
      build.enqueue
    end
  end
end
