require 'spec_helper'
require 'rexml/document'

describe BuildsController do
  let(:project) { projects(:big_rails_app) }

  describe "#create" do
    it "should create a build" do
      post :create, :build => {:sha => "deadbeef", :queue => "master", :project => project}

      b = Build.last
      b.queue.should == :master
      b.sha.should == "deadbeef"
      b.state.should == :partitioning
    end

    it "should enqueue a build partitioning job" do
      Resque.should_receive(:enqueue).with(BuildPartitioningJob, kind_of(Integer))
      post :create, :build => {:sha => "deadbeef", :queue => "master", :project => project}
    end
  end

  describe "#index" do
    render_views

    before do
      @build1 = Build.create!(:queue => 'master', :state => :succeeded, :sha => 'abc', :project => project)
      @build2 = Build.create!(:queue => 'master', :state => :error, :sha => 'def', :project => project)
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
      before { Build.create!(:queue => 'master', :state => :running, :sha => 'abc', :project => project) }

      it "should return 'Building' for activity" do
        get :status_report, :format => :xml
        doc = Nokogiri::XML(response.body)
        element = doc.at_xpath("/Projects/Project[@name='web-master']")

        element['activity'].should == 'Building'
      end
    end

    context "with a completed build" do
      before { Build.create!(:queue => 'master', :state => :failed, :sha => 'abc', :project => project) }

      it "should return 'CheckingModifications' for activity" do
        get :status_report, :format => :xml
        doc = Nokogiri::XML(response.body)
        element = doc.at_xpath("/Projects/Project[@name='web-master']")

        element['activity'].should == 'CheckingModifications'
      end
    end
  end

  describe "#push_receive_hook" do
    before do
      @payload = JSON.load(FIXTURE_PATH.join("sample_github_webhook_payload.json").read)
    end

    context "on the master branch" do
      before do
        @payload["ref"] = "refs/heads/master"
      end

      it "should create a new build" do
        post :push_receive_hook, :payload => @payload
        Build.where(:sha => @payload["after"]).exists?.should be_true
      end
    end

    context "on the master branch" do
      before do
        @payload["ref"] = "refs/heads/topic"
      end

      it "should create a new build" do
        expect {
          post :push_receive_hook, :payload => @payload
        }.to_not change(Build, :count)
      end
    end
  end
end
