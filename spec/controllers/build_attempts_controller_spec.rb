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
      expect(build_attempt.log_streamer_port).to be_nil
    end

    it "should set log streamer port if provided" do
      build_attempt = FactoryGirl.create(:build_attempt)
      expect(build_attempt.state).to eq(:runnable)
      expect(build_attempt.started_at).to be_nil
      expect(build_attempt.builder).to be_nil
      expect(build_attempt.log_streamer_port).to be_nil

      post :start, :id => build_attempt.to_param, :builder => "build01", :logstreamer_port => 10000, :format => :json
      expect(response).to be_success

      build_attempt.reload
      expect(build_attempt.state).to eq(:running)
      expect(build_attempt.started_at).not_to be_nil
      expect(build_attempt.builder).to eq("build01")
      expect(build_attempt.log_streamer_port).to eq(10000)
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

  describe "#stream_logs" do
    it "should return 404 for build attempt that doesn't have log streaming port" do
      build_attempt = FactoryGirl.create(:build_attempt, :log_streamer_port => nil)

      get :stream_logs, :id => build_attempt.to_param, :format => :html
      expect(response.code). to eq("404")
    end
  end

  describe "#stream_logs_chunk" do
    it "should return error for build attempt that doesn't have log streaming port" do
      build_attempt = FactoryGirl.create(:build_attempt, :log_streamer_port => nil)

      get :stream_logs_chunk, :id => build_attempt.to_param, :format => :json
      expect(response.code).to eq("500")
      expect(JSON.parse(response.body)['error']).to eq("No log streaming available for this build attempt")
    end

    it "should return error for build attempt that doesn't have builder" do
      build_attempt = FactoryGirl.create(:build_attempt, :log_streamer_port => 10000, :builder => nil)

      get :stream_logs_chunk, :id => build_attempt.to_param, :format => :json
      expect(response.code).to eq("500")
      expect(JSON.parse(response.body)['error']).to eq("No log streaming available for this build attempt")
    end

    context "logstreamer not successful" do
      before do
        stub_request(:get, "http://worker.example.com:10000/build_attempts/100/log/stdout.log?maxBytes=250000&start=0").to_return(:status => 500, :body => "{}", :headers => {})
      end
      it "should return error when logstreamer errors" do
        build_attempt = FactoryGirl.create(:build_attempt, :log_streamer_port => 10000, :builder => 'worker.example.com', :id => 100)

        get :stream_logs_chunk, :id => build_attempt.to_param, :format => :json
        expect(response.code).to eq("500")
        expect(JSON.parse(response.body)['error']).to eq("unable to reach log streamer")
      end
    end

    context "logstreamer successful" do
      let (:logstreamer_body) { '{"Start" : 0, "Contents" : "This is a test\n", "BytesRead": 15, "LogName": "stdout.log"}' }
      before do
        stub_request(:get, "http://worker.example.com:10000/build_attempts/100/log/stdout.log?maxBytes=250000&start=0").to_return(:status => 200, :body => logstreamer_body, :headers => {})
      end
      it "should proxy request from logstreamer and add build attempt state" do
        build_attempt = FactoryGirl.create(:build_attempt, :log_streamer_port => 10000, :builder => 'worker.example.com', :id => 100, state: :running)

        get :stream_logs_chunk, :id => build_attempt.to_param, :format => :json
        expect(response.code).to eq("200")
        response_hash = JSON.parse(response.body)
        logstreamer_hash = JSON.parse(logstreamer_body)
        expect(response_hash.merge(logstreamer_hash)).to eq(response_hash) # check that response_hash includes all attributes from logstreamer_hash
        expect(response_hash['state']).to eq("running")
      end
    end
  end
end
