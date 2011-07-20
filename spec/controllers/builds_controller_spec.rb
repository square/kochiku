require 'spec_helper'

describe BuildsController do

  describe "#create" do
    before do
      @project = projects(:big_rails_app)
      @payload = JSON.load(FIXTURE_PATH.join("sample_github_webhook_payload.json").read)
    end

    context "when the pushed branch matches the project branch" do
      before do
        @payload["ref"] = "refs/heads/#{@project.branch}"
      end

      it "should create a new build" do
        post :create, :project_id => @project.to_param, :payload => @payload
        Build.where(:project_id => @project.id, :sha => @payload["after"]).exists?.should be_true
      end
    end

    context "when the pushed branch does not match the project branch" do
      before do
        @payload["ref"] = "refs/heads/topic"
      end

      it "should have no effect" do
        expect {
          post :create, :project_id => @project.to_param, :payload => @payload
        }.to_not change(Build, :count)
      end
    end
  end

end
