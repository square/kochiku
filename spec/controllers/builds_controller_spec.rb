require 'spec_helper'

describe BuildsController do

  describe "#create" do

    context "via github" do
      before do
        @project = FactoryGirl.create(:big_rails_project)
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

      it "should find an existing build" do
        post :create, :project_id => project_param, :build => build_info
        expected_url = response.location

        expect {
          post :create, :project_id => project_param, :build => build_info
        }.to_not change { Build.count }

        response.location.should == expected_url
      end
    end
  end

  describe "#request_build" do
    context "when a non existent project is specified" do
      it "creates the project" do
        expect{ post :create, :project_id => "foobar", :build => {:ref => "asdf"} }.to change{Project.count}.by(1)
      end

      it "creates a build if a ref is given" do
        expect{ post :create, :project_id => "foobar", :build => {:ref => "asdf"} }.to change{Build.count}.by(1)
      end

      it "doesn't create a build if no ref is given" do
        expect{ post :create, :project_id => "foobar", :build => {:ref => nil }}.to_not change{Build.count}
      end
    end

    context "when the project exists" do
      let(:project){ FactoryGirl.create(:project) }

      it "creates the build if a ref is given" do
        expect{ post :create, :project_id => project.to_param, :build => {:ref => "asdf"} }.to change{Build.count}.by(1)
      end

      it "doesn't create a build if no ref is given" do
        expect{ post :create, :project_id => project.to_param, :build => {:ref => nil} }.to_not change{Build.count}
      end
    end

  end

  describe "#abort" do
    before do
      @build = FactoryGirl.create(:build)
      put :abort, :project_id => @build.project.to_param, :id => @build.to_param
    end

    it "redirects back to the build page" do
      response.should redirect_to(project_build_path(@build.project, @build))
    end

    it "sets the build's state to aborted" do
      @build.reload.state.should == :aborted
    end
  end
end
