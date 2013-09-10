require 'spec_helper'
require 'rexml/document'

describe ProjectsController do
  render_views

  describe "#index" do
    let(:a) { FactoryGirl.create(:project, name: 'aster') }
    let(:b) { FactoryGirl.create(:project, name: 'buckeye') }
    let(:c) { FactoryGirl.create(:project, name: 'creosote') }

    it "shows projects in order" do
      b; a; c
      get :index
      assigns(:projects).map(&:name).should == %w{aster buckeye creosote}
    end
  end

  describe "#ci_projects" do
    let(:repository) { FactoryGirl.create(:repository) }
    let!(:ci_project) { FactoryGirl.create(:project, :name => repository.repository_name) }
    let!(:non_ci_project) { FactoryGirl.create(:project, :name => repository.repository_name + "-pull_requests") }

    it "only shows the ci project" do
      get :ci_projects
      response.should be_success
      doc = Nokogiri::HTML(response.body)
      elements = doc.css(".projects .ci-build-info")
      elements.size.should == 1
    end
  end

  describe "#show" do
    render_views

    let(:project) { FactoryGirl.create(:big_rails_project) }
    let!(:build1) { FactoryGirl.create(:build, :project => project, :state => :succeeded) }
    let!(:build2) { FactoryGirl.create(:build, :project => project, :state => :errored) }

    it "should return an rss feed of builds" do
      get :show, :id => project.to_param, :format => :rss
      doc = REXML::Document.new(response.body)
      items = doc.elements.to_a("//channel/item")
      items.length.should == Build.count
      items.first.elements.to_a("title").first.text.should == "Build Number #{build2.id} failed"
      items.last.elements.to_a("title").first.text.should == "Build Number #{build1.id} success"
    end
  end

  describe "#status_report" do
    render_views
    let(:repository) { FactoryGirl.create(:repository) }
    let(:project) { FactoryGirl.create(:project, :repository => repository, :name => repository.repository_name) }

    context "when a project has no builds" do
      before { project.builds.should be_empty }

      it "should return 'Unknown' for activity" do
        get :status_report, :format => :xml
        response.should be_success

        doc = Nokogiri::XML(response.body)
        element = doc.at_xpath("/Projects/Project[@name='#{project.name}']")

        element['activity'].should == 'Unknown'
      end
    end

    context "with a in-progress build" do
      let!(:build) { FactoryGirl.create(:build, :state => :running, :project => project) }

      it "should return 'Building' for activity" do
        get :status_report, :format => :xml
        response.should be_success

        doc = Nokogiri::XML(response.body)
        element = doc.at_xpath("/Projects/Project[@name='#{project.name}']")

        element['activity'].should == 'Building'
      end
    end

    context "with a completed build" do
      let!(:build) { FactoryGirl.create(:build, :state => :failed, :project => project) }

      it "should return 'CheckingModifications' for activity" do
        get :status_report, :format => :xml
        response.should be_success

        doc = Nokogiri::XML(response.body)
        element = doc.at_xpath("/Projects/Project[@name='#{project.name}']")

        element['activity'].should == 'CheckingModifications'
      end
    end
  end
end
