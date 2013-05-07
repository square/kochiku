require 'spec_helper'

describe BuildsController do
  describe "#create" do
    let(:repo) { FactoryGirl.create(:repository) }
    before do
      @action = :create
      @params = {:repo_url => repo.url}
    end

    context "via github" do
      before do
        @project = FactoryGirl.create(:big_rails_project, :repository => repo)
        @payload = JSON.load(FIXTURE_PATH.join("sample_github_webhook_payload.json").read)
      end

      context "when the pushed branch matches the project branch" do
        before do
          @payload["ref"] = "refs/heads/#{@project.branch}"
        end

        it "should create a new build" do
          post @action, @params.merge(:project_id => @project.to_param, :payload => @payload)
          Build.where(:project_id => @project, :ref => @payload["after"]).exists?.should be_true
        end
      end

      context "when the pushed branch does not match the project branch" do
        before do
          @payload["ref"] = "refs/heads/topic"
        end

        it "should have no effect" do
          expect {
            post @action, @params.merge(:project_id => @project.to_param, :payload => @payload)
          }.to_not change(Build, :count)

          response.should be_success
        end
      end

      context "when the project does not exist" do
        it "should raise RecordNotFound so Rails returns a 404" do
          expect {
            post @action, @params.merge(:project_id => 'not_here', :payload => @payload)
          }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end

    context "developer initiated" do
      before do
        @params = {:repo_url => repo.url}
      end

      let(:project_param) { "ganymede-hammertime" }
      let(:build_info) do
        {
          :hostname => "ganymede",
          :project => "hammertime",
          :ref => "30b111147d9a245468c6650f54de5c16584bc154"
        }
      end

      it "should create a new project if one does not exist" do
        expect {
          post @action, @params.merge(:project_id => project_param, :build => build_info)
        }.to change { Project.exists?(:name => project_param) }.from(false).to(true)
      end

      context "when the pushed branch has already been built" do
        it "has no effect" do
          project = FactoryGirl.create(:project, :repository => repo)
          build = FactoryGirl.create(:build, :project => project, :ref => "30b111147d9a245468c6650f54de5c16584bc154")
          expect {
            post @action, @params.merge(:project_id => project_param, :build => build_info)
            response.should be_success
          }.to_not change(Build, :count)
          response.headers["Location"].should == project_build_url(project, build)
        end

        it "rebuilds if the sha is on a different repo" do
          project = FactoryGirl.create(:project)
          build = FactoryGirl.create(:build, :project => project, :ref => "30b111147d9a245468c6650f54de5c16584bc154")
          expect {
            post @action, @params.merge(:project_id => project_param, :build => build_info)
            response.should be_success
          }.to change(Build, :count)
          response.headers["Location"].should_not == project_build_url(project, build)
        end
      end

      it "should create a repo if one does not exist" do
        Repository.destroy_all
        expect {
          post @action, @params.merge(:project_id => project_param, :build => build_info)
        }.to change(Repository, :count).by(1)
        Repository.last.url.should == repo.url
      end

      it "sets automerge when param given" do
        post @action, @params.merge(:project_id => project_param, :build => build_info, :auto_merge => "1")
        Build.last.auto_merge.should == true
      end

      it "sets branch when param given" do
        post @action, @params.merge(:project_id => project_param, :build => build_info.merge(:branch => "sticky-buddy"))
        Build.last.branch.should == "sticky-buddy"
      end

      it "defaults to false automerge when param not given" do
        post @action, @params.merge(:project_id => project_param, :build => build_info)
        Build.last.auto_merge.should == false
      end

      it "should create a new build" do
        Build.exists?(:ref => build_info[:ref]).should be_false
        post @action, @params.merge(:project_id => project_param, :build => build_info)
        Build.exists?(:project_id => assigns(:project), :ref => build_info[:ref]).should be_true
      end

      it "should return the build info page in the location header" do
        post @action, @params.merge(:project_id => project_param, :build => build_info)

        new_build = Build.where(:project_id => assigns(:project), :ref => build_info[:ref]).first
        new_build.should be_present

        response.location.should == project_build_url(project_param, new_build)
      end

      it "should find an existing build" do
        post @action, @params.merge(:project_id => project_param, :build => build_info)
        expected_url = response.location

        expect {
          post @action, @params.merge(:project_id => project_param, :build => build_info)
        }.to_not change { Build.count }

        response.location.should == expected_url
      end
    end
  end

  describe "#request_build" do
    before do
      @action = :request_build
      @params = {}
    end

    context "when a non existent project is specified" do
      let(:repo) { FactoryGirl.create(:repository) }

      before do
        @params = {:repo_url => repo.url}
      end
      it "creates the project" do
        expect{ post @action, @params.merge(:project_id => "foobar", :build => {:ref => "asdf"}) }.to change{Project.count}.by(1)
      end

      it "creates a build if a ref is given" do
        expect{ post @action, @params.merge(:project_id => "foobar", :build => {:ref => "asdf"}) }.to change{Build.count}.by(1)
        Build.last.queue.should == :developer
      end

      it "doesn't create a build if no ref is given" do
        expect{ post @action, @params.merge(:project_id => "foobar", :build => {:ref => nil })}.to_not change{Build.count}
        flash[:error].should start_with("Error adding build!")
      end

      it "doesn't create a build if the ref already exists" do
        project = FactoryGirl.create(:project, :name => repo.repository_name)
        build = FactoryGirl.create(:build, :state => :succeeded, :project => project, :branch => "master", :ref => "deadbeef12345")
        GitRepo.stub(:current_master_ref).and_return(build.ref)

        expect{ post @action, @params.merge(:project_id => project.to_param, :build => {:ref => build.ref })}.to_not change{Build.count}
        flash[:error].should start_with("Error adding build!")
      end
    end

    context "when the project is the ci project" do
      before do
        GitRepo.stub(:current_master_ref).and_return("some-sha")
      end
      let(:repository){ FactoryGirl.create(:repository, :url => "git@git.squareup.com:square/web.git") }
      let(:project){ FactoryGirl.create(:project, :name => "web", :repository => repository) }

      it "creates the build if a ref is given" do
        expect{
          post @action, @params.merge(:project_id => project.to_param, :build => {:ref => "asdf"})
          response.should be_redirect
        }.to change(Build, :count).by(1)
        build = Build.last
        build.project.should == project
        build.queue.should == :ci
        build.ref.should_not == "asdf"
      end

      it "create a build if no ref is given" do
        expect{
          post @action, :project_id => project.to_param
          response.should be_redirect
        }.to change(Build, :count).by(1)
        build = Build.last
        build.project.should == project
        build.queue.should == :ci
        build.ref.should_not be_blank
      end
    end

    context "when the project exists" do
      let(:project){ FactoryGirl.create(:project) }

      it "creates the build if a ref is given" do
        expect{ post :create, @params.merge(:project_id => project.to_param, :build => {:ref => "asdf"}) }.to change{Build.count}.by(1)
      end

      it "doesn't create a build if no ref is given" do
        expect{ post :create, @params.merge(:project_id => project.to_param, :build => {:ref => nil}) }.to_not change{Build.count}
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

    # spot-check that it does some abort action
    it "sets the build's state to aborted" do
      @build.reload.state.should == :aborted
    end
  end

  describe "#toggle_auto_merge" do
    before do
      @build = FactoryGirl.create(:build, :auto_merge => true)
    end

    it "aborts the auto_merge" do
      post :toggle_auto_merge, :id => @build.id, :project_id => @build.project.name, :auto_merge => false
      response.should redirect_to(project_build_path(@build.project, @build))
      @build.reload.auto_merge.should be_false
    end

    it "enables the auto_merge" do
      @build.update_attributes(:auto_merge => false)
      post :toggle_auto_merge, :id => @build.id, :project_id => @build.project.name, :auto_merge => true
      response.should redirect_to(project_build_path(@build.project, @build))
      @build.reload.auto_merge.should be_true
    end
  end

  describe "auto merge" do
    render_views
    let(:project) { FactoryGirl.create(:project) }
    let(:build) { FactoryGirl.create(:build, :project => project, :queue => queue) }
    let(:queue) { :developer }
    before do
      @action = :show
      @params = {:id => build.id, :project_id => project.name}
    end

    it "renders the enable auto merge checkbox" do
      get @action, @params
      doc = Nokogiri::HTML(response.body)
      elements = doc.css("input[name=auto_merge]")
      elements.size.should == 1
      elements.first['checked'].should be_blank
    end

    context "for auto merge enabled builds" do
      let(:build) { FactoryGirl.create(:build, :project => project, :queue => queue, :auto_merge => true) }
      it "renders the enable auto merge checkbox" do
        get @action, @params
        doc = Nokogiri::HTML(response.body)
        elements = doc.css("input[name=auto_merge]")
        elements.size.should == 1
        elements.first['checked'].should be_present
      end
    end

    context "for ci builds" do
      let(:queue) { :ci }

      it "renders the auto merge checkbox disabled" do
        get @action, @params
        doc = Nokogiri::HTML(response.body)
        elements = doc.css("input[name=auto_merge]")
        elements.size.should == 1
        elements.first['disabled'].should be_present
      end
    end
  end

  describe "#rebuild_failed_parts" do
    let(:build) { FactoryGirl.create(:build) }
    let(:parts) { (1..3).map { FactoryGirl.create(:build_part, :build_instance => build) } }

    subject { post :rebuild_failed_parts, :project_id => build.project.to_param, :id => build.id }

    context "happy path" do
      before do
        @attempt_1 = FactoryGirl.create(:build_attempt, :build_part => parts[0], :state => :failed)
        @attempt_2 = FactoryGirl.create(:build_attempt, :build_part => parts[1], :state => :failed)
        @attempt_3 = FactoryGirl.create(:build_attempt, :build_part => parts[1], :state => :errored)
        @attempt_4 = FactoryGirl.create(:build_attempt, :build_part => parts[2], :state => :passed)
      end

      it "rebuilds all failed attempts" do
        build.build_parts.failed_or_errored.count.should == 2
        subject
        build.reload.build_parts.failed.count.should be_zero
        build.build_attempts.count.should == 6
      end

      it "only enqueues one build attempt for each failed build part" do
        subject
        parts[0].reload.build_attempts.count.should == 2
        parts[1].reload.build_attempts.count.should == 3

        expect {
          # repost to test idempotency
          post :rebuild_failed_parts, :project_id => build.project.to_param, :id => build.id
        }.to_not change(BuildAttempt, :count)
      end
    end

    context "an successful prior build attempt should not be rebuilt" do
      it "does something" do
        attempt_1 = FactoryGirl.create(:build_attempt, :build_part => parts[1], :state => :passed)
        attempt_2 = FactoryGirl.create(:build_attempt, :build_part => parts[1], :state => :failed)

        expect { subject }.to_not change(BuildAttempt, :count)
      end
    end
  end
end
