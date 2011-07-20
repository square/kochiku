require 'spec_helper'

describe ProjectsController do
  describe "#status_report" do
    render_views
    before do
      @project = projects(:big_rails_app)
    end

    context "when a project has no builds" do
      before { @project.builds.should be_empty }

      it "should return 'Unknown' for activity" do
        get :status_report, :format => :xml
        doc = Nokogiri::XML(response.body)
        element = doc.at_xpath("/Projects/Project[@name='#{@project.name_with_branch}']")

        element['activity'].should == 'Unknown'
      end
    end

    context "with a in-progress build" do
      before do
        @project.builds.create!(:queue => 'master', :state => :running, :sha => 'abc')
      end

      it "should return 'Building' for activity" do
        get :status_report, :format => :xml
        doc = Nokogiri::XML(response.body)
        element = doc.at_xpath("/Projects/Project[@name='#{@project.name_with_branch}']")

        element['activity'].should == 'Building'
      end
    end

    context "with a completed build" do
      before do
        @project.builds.create!(:queue => 'master', :state => :failed, :sha => 'abc')
      end

      it "should return 'CheckingModifications' for activity" do
        get :status_report, :format => :xml
        doc = Nokogiri::XML(response.body)
        element = doc.at_xpath("/Projects/Project[@name='#{@project.name_with_branch}']")

        element['activity'].should == 'CheckingModifications'
      end
    end
  end

  describe "#push_receive_hook" do
    before do
      @project = projects(:big_rails_app)
      @payload = JSON.load(FIXTURE_PATH.join("sample_github_webhook_payload.json").read)
    end

    context "for a branch that Kochiku is tracking" do
      before do
        @payload["ref"] = "refs/heads/#{@project.branch}"
      end

      it "should create a new build" do
        post :push_receive_hook, :id => @project.to_param, :payload => @payload
        Build.where(:project_id => @project.id, :sha => @payload["after"]).exists?.should be_true
      end
    end

    context "for a branch that Kochiku is not tracking" do
      before do
        @payload["ref"] = "refs/heads/topic"
      end

      it "should create a new build" do
        expect {
          post :push_receive_hook, :id => @project.to_param, :payload => @payload
        }.to_not change(Build, :count)
      end
    end
  end

end