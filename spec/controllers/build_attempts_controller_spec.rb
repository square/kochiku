require 'spec_helper'

describe BuildAttemptsController do
  describe "#start" do
    it "should set the start time and state of the build attempt" do
      build_attempt = FactoryGirl.create(:build_attempt)
      expect(build_attempt.state).to eq(:runnable)
      expect(build_attempt.started_at).to be_nil
      expect(build_attempt.builder).to be_nil

      post :start, :id => build_attempt.to_param, :builder => "build01", :format => :json
      expect(response).to be_success

      build_attempt.reload
      expect(build_attempt.state).to eq(:running)
      expect(build_attempt.started_at).not_to be_nil
      expect(build_attempt.builder).to eq("build01")
    end

    it "should return aborted if the build_attempt is aborted" do
      build_attempt = FactoryGirl.create(:build_attempt, :state => :aborted)

      post :start, :id => build_attempt.to_param, :builder => "build01", :format => :json
      expect(response).to be_success

      expect(JSON.parse(response.body)["build_attempt"]["state"]).to eq("aborted")
      expect(build_attempt.reload.state).to eq(:aborted)
    end
  end

  describe "#finish" do
    it "should set the finish time and state of the build attempt" do
      build_attempt = FactoryGirl.create(:build_attempt)
      expect(build_attempt.state).to eq(:runnable)
      expect(build_attempt.finished_at).to be_nil

      post :finish, :id => build_attempt.to_param, :state => "passed", :format => :json
      expect(response).to be_success

      build_attempt.reload
      expect(build_attempt.state).to eq(:passed)
      expect(build_attempt.finished_at).not_to be_nil
    end

    it "should return errors when the build_attempt fails to start" do
      build_attempt = FactoryGirl.create(:build_attempt)

      post :finish, :id => build_attempt.to_param, :state => "invalid-state", :format => :json
      expect(response.code).to eq("422")

      expect(JSON.parse(response.body)['state']).not_to be_blank
    end

    it "should redirect to the build_part's URL for HTML requests" do
      build_attempt = FactoryGirl.create(:build_attempt)

      post :finish, :id => build_attempt.to_param, :state => "aborted", :format => :html

      expect(response.code).to eq("302")
      build_attempt.reload
      expect(build_attempt.state).to eq(:aborted)
    end
  end
end
