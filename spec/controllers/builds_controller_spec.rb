require 'spec_helper'
require 'rexml/document'

describe BuildsController do
  describe "#create" do
    it "should create a build" do
      post :create, :build => {:sha => "deadbeef", :queue => "master"}

      b = Build.last
      b.queue.should == :master
      b.sha.should == "deadbeef"
      b.state.should == :partitioning
    end

    it "should enqueue a build partitioning job" do
      Resque.should_receive(:enqueue).with(BuildPartitioningJob, kind_of(Integer))
      post :create, :build => {:sha => "deadbeef", :queue => "master"}
    end
  end

  describe "#index" do
    render_views

    before do
      @build1 = Build.create!(:queue => 'master', :state => :succeeded, :sha => 'abc')
      @build2 = Build.create!(:queue => 'master', :state => :error, :sha => 'def')
    end

    it "should return an rss feed of builds" do
      get :index, :format => :rss
      doc = REXML::Document.new(response.body)
      items = doc.elements.to_a("//channel/item")
      items.length.should == Build.count
      items.first.elements.to_a("title").first.text.should == "Build Number #{@build2.id} failed"
      items.last.elements.to_a("title").first.text.should == "Build Number #{@build1.id} success"
    end
  end

  describe "#status_report" do
    render_views

    context "without any builds" do
      it "should return 'Unknown' for activity" do
        get :status_report, :format => :xml
        doc = Nokogiri::XML(response.body)
        element = doc.at_xpath("/Projects/Project[@name='web-master']")

        element['activity'].should == 'Unknown'
      end
    end

    context "with a in-progress build" do
      before { Build.create!(:queue => 'master', :state => :running, :sha => 'abc') }

      it "should return 'Building' for activity" do
        get :status_report, :format => :xml
        doc = Nokogiri::XML(response.body)
        element = doc.at_xpath("/Projects/Project[@name='web-master']")

        element['activity'].should == 'Building'
      end
    end

    context "with a completed build" do
      before { Build.create!(:queue => 'master', :state => :failed, :sha => 'abc') }

      it "should return 'CheckingModifications' for activity" do
        get :status_report, :format => :xml
        doc = Nokogiri::XML(response.body)
        element = doc.at_xpath("/Projects/Project[@name='web-master']")

        element['activity'].should == 'CheckingModifications'
      end
    end
  end
end
