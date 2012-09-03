require 'spec_helper'

describe BuildAttemptsController do
  describe "#start" do
    it "should set the start time and state of the build attempt" do
      build_attempt = FactoryGirl.create(:build_attempt)
      build_attempt.state.should == :runnable
      build_attempt.started_at.should be_nil
      build_attempt.builder.should be_nil

      post :start, :id => build_attempt.to_param, :builder => "build01", :format => :json
      response.should be_success

      build_attempt.reload
      build_attempt.state.should == :running
      build_attempt.started_at.should_not be_nil
      build_attempt.builder.should == "build01"
    end

    it "should return aborted if the build_attempt is aborted" do
      build_attempt = FactoryGirl.create(:build_attempt, :state => :aborted)

      post :start, :id => build_attempt.to_param, :builder => "build01", :format => :json
      response.should be_success

      JSON.parse(response.body)["build_attempt"]["state"].should == "aborted"
      build_attempt.reload.state.should == :aborted
    end
  end

  describe "#finish" do
    it "should set the finish time and state of the build attempt" do
      build_attempt = FactoryGirl.create(:build_attempt)
      build_attempt.state.should == :runnable
      build_attempt.finished_at.should be_nil

      post :finish, :id => build_attempt.to_param, :state => "passed", :format => :json
      response.should be_success

      build_attempt.reload
      build_attempt.state.should == :passed
      build_attempt.finished_at.should_not be_nil
    end

    it "should return errors when the build_attempt fails to start" do
      build_attempt = FactoryGirl.create(:build_attempt)

      post :finish, :id => build_attempt.to_param, :state => "invalid-state", :format => :json
      response.code.should == "422"

      JSON.parse(response.body)['state'].should_not be_blank
    end

    it "should redirect to the build_part's URL for HTML requests" do
      build_attempt = FactoryGirl.create(:build_attempt)

      post :finish, :id => build_attempt.to_param, :state => "aborted", :format => :html

      response.code.should == "302"
      build_attempt.reload
      build_attempt.state.should == :aborted
    end
  end
end
