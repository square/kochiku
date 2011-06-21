require 'spec_helper'

describe BuildsController do
  describe "#create" do
    it "should create a build" do
      post :create, :build => {:sha => "deadbeef", :queue => "master"}

      b = Build.last
      b.queue.should == :master
      b.sha.should == "deadbeef"
      b.state.should == :partitioning
    end

    it "should enqueue a build partitioning job" do
      Resque.should_receive(:enqueue).with(BuildPartitioningJob, kind_of(Integer))
      post :create, :build => {:sha => "deadbeef", :queue => "master"}
    end
  end
end
