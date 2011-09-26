require 'spec_helper'
require 'rexml/document'

describe ProjectsController do
  describe "#show" do
    render_views

    before do
      @project = FactoryGirl.create(:big_rails_project)
      @build1 = FactoryGirl.create(:build, :project => @project, :state => :succeeded)
      @build2 = FactoryGirl.create(:build, :project => @project, :state => :errored)
    end

    it "should return an rss feed of builds" do
      get :show, :id => @project.to_param, :format => :rss
      doc = REXML::Document.new(response.body)
      items = doc.elements.to_a("//channel/item")
      items.length.should == Build.count
      items.first.elements.to_a("title").first.text.should == "Build Number #{@build2.id} failed"
      items.last.elements.to_a("title").first.text.should == "Build Number #{@build1.id} success"
    end
  end

  describe "#build_time_history" do
    it "should render json of time histories" do
      project = FactoryGirl.create(:big_rails_project)
      build1 = FactoryGirl.create(:build, :project => project, :state => :succeeded, :created_at => Time.now - 1235.seconds)
      part1 = FactoryGirl.create(:build_part, :build_instance => build1)
      attempt1 = FactoryGirl.create(:build_attempt, :build_part => part1, :finished_at => Time.now)
      build2 = FactoryGirl.create(:build, :project => project, :state => :succeeded, :created_at => Time.now - 600.seconds)
      part2 = FactoryGirl.create(:build_part, :build_instance => build2)
      attempt2 = FactoryGirl.create(:build_attempt, :build_part => part2, :finished_at => Time.now)

      project2 = FactoryGirl.create(:project, :name => 'another-name')
      build3 = FactoryGirl.create(:build, :project => project2, :state => :succeeded, :created_at => Time.now - 1200.seconds)
      part3 = FactoryGirl.create(:build_part, :build_instance => build3)
      attempt3 = FactoryGirl.create(:build_attempt, :build_part => part3, :finished_at => Time.now)

      get :build_time_history, {:format => 'json', :project_id => 'web'}
      JSON.parse(response.body).should == [[build1.id,21], [build2.id,10]]
    end

    it "should not include incomplete builds" do
      attempt = FactoryGirl.create(:build_attempt, :finished_at => nil)
      build = attempt.build_part.build_instance
      get :build_time_history, {:format => 'json', :project_id => build.project.to_param}
      response.body.should_not include(build.id)
    end

    it "should not included errored builds" do
      attempt = FactoryGirl.create(:build_attempt)
      build = attempt.build_part.build_instance
      build.update_attributes!(:state => :errored)
      get :build_time_history, {:format => 'json', :project_id => build.project.to_param}
      response.body.should_not include(build.id)
    end
  end

  describe "#status_report" do
    render_views
    before do
      @project = FactoryGirl.create(:big_rails_project)
    end

    context "when a project has no builds" do
      before { @project.builds.should be_empty }

      it "should return 'Unknown' for activity" do
        get :status_report, :format => :xml
        doc = Nokogiri::XML(response.body)
        element = doc.at_xpath("/Projects/Project[@name='#{@project.name}']")

        element['activity'].should == 'Unknown'
      end
    end

    context "with a in-progress build" do
      before do
        FactoryGirl.create(:build, :state => :running, :project => @project)
      end

      it "should return 'Building' for activity" do
        get :status_report, :format => :xml
        doc = Nokogiri::XML(response.body)
        element = doc.at_xpath("/Projects/Project[@name='#{@project.name}']")

        element['activity'].should == 'Building'
      end
    end

    context "with a completed build" do
      before do
        FactoryGirl.create(:build, :state => :failed, :project => @project)
      end

      it "should return 'CheckingModifications' for activity" do
        get :status_report, :format => :xml
        doc = Nokogiri::XML(response.body)
        element = doc.at_xpath("/Projects/Project[@name='#{@project.name}']")

        element['activity'].should == 'CheckingModifications'
      end
    end
  end

end