require 'spec_helper'

describe BuildsController do

  describe "#create" do

    context "via github" do
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
          Build.where(:project_id => @project, :ref => @payload["after"]).exists?.should be_true
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

          response.should be_success
        end
      end

      context "when the project does not exist" do
        it "should raise RecordNotFound so Rails returns a 404" do
          expect {
            post :create, :project_id => 'not_here', :payload => @payload
          }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end

    context "developer initiated" do
      let(:project_param) { "ganymede-hammertime" }
      let(:build_info) do
        {
          :hostname => "ganymede",
          :project => "hammertime",
          :origin_url => "git@github.com:square/hammertime.git",
          :ref => "30b111147d9a245468c6650f54de5c16584bc154"
        }
      end

      it "should create a new project if one does not exist" do
        expect {
          post :create, :project_id => project_param, :build => build_info
        }.to change { Project.exists?(:name => project_param) }.from(false).to(true)
      end

      it "should create a new build" do
        Build.exists?(:ref => build_info[:ref]).should be_false
        post :create, :project_id => project_param, :build => build_info
        Build.exists?(:project_id => assigns(:project), :ref => build_info[:ref]).should be_true
      end

      it "should return the build info page in the location header" do
        post :create, :project_id => project_param, :build => build_info

        new_build = Build.where(:project_id => assigns(:project), :ref => build_info[:ref]).first
        new_build.should be_present

        response.location.should == project_build_url(project_param, new_build)
      end
    end
  end

end
