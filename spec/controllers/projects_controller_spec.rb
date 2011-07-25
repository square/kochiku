require 'spec_helper'
require 'rexml/document'

describe ProjectsController do
  describe "#show" do
    render_views

    before do
      @project = FactoryGirl.create(:big_rails_project)
      @build1 = Build.create!(:queue => :ci, :state => :succeeded, :ref => 'abc', :project => @project)
      @build2 = Build.create!(:queue => :ci, :state => :error, :ref => 'def', :project => @project)
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
        @project.builds.create!(:queue => :ci, :state => :running, :ref => 'abc')
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
        @project.builds.create!(:queue => :ci, :state => :failed, :ref => 'abc')
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