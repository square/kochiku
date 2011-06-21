require 'spec_helper'

describe BuildsController do
  describe "#create" do
    it "should create a build" do
      post :create, :build => {:sha => "deadbeef", :queue => "master"}

      b = Build.last
      b.queue.should == :master
      b.sha.should == "deadbeef"
      b.state.should == :preparing
    end

    
  end
end
