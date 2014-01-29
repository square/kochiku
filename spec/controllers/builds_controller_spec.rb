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

      it "sets merge_on_success when param given" do
        post @action, @params.merge(:project_id => project_param, :build => build_info, :merge_on_success => "1")
        Build.last.merge_on_success.should == true
      end

      it "defaults merge_on_success to false when param not given" do
        post @action, @params.merge(:project_id => project_param, :build => build_info)
        Build.last.merge_on_success.should == false
      end

      it "sets branch when param given" do
        post @action, @params.merge(:project_id => project_param, :build => build_info.merge(:branch => "sticky-buddy"))
        Build.last.branch.should == "sticky-buddy"
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
    let(:branch) { "test/branch" }
    let(:branch_head_sha) { "4b41fe773057b2f1e2063eb94814d32699a34541" }



    context "when a non existent project is specified" do
      it "throws not found exception" do
        expect {
          post :request_build, {:project_id => "does-not-exist", :build => {:branch => branch}}
        }.to raise_exception(ActiveRecord::RecordNotFound)
      end
    end

    context "when the project exists" do
      let(:project) { FactoryGirl.create(:project) }

      before do
        @action = :request_build

        build_ref_info = <<RESPONSE
{
  "ref": "refs/heads/#{branch}",
  "url": "#{project.repository.base_api_url}/git/refs/heads/#{branch}",
  "object": {
    "sha": "#{branch_head_sha}",
    "type": "commit",
    "url": "#{project.repository.base_api_url}/git/commits/#{branch_head_sha}"
  }
}
RESPONSE
        stub_request(:get, "#{project.repository.base_api_url}/git/refs/heads/#{branch}").to_return(:status => 200, :body => build_ref_info)
      end

      it "creates the build if a branch is given" do
        expect {
          post @action, {:project_id => project.to_param, :build => {:branch => branch}}
        }.to change { Build.count }.by(1)
        build = Build.last
        build.project.should == project
        build.branch.should == branch
        build.ref.should == branch_head_sha
      end

      context "and project is main project" do
        let(:repo) { FactoryGirl.create(:repository, url: 'git@github.com:square/test-repo.git') }
        let(:project) { FactoryGirl.create(:project, :name => repo.repository_name, :repository => repo) }

        before do
          project.should be_main
        end

        it "creates the build for main project if no branch is given" do
          GitRepo.stub(:sha_for_branch).and_return("deadbeef")

          expect {
            post @action, {:project_id => project.to_param}
          }.to change { Build.count }.by(1)
          build = Build.last
          build.project.should == project
          build.branch.should == "master"
          build.ref.should == "deadbeef"
        end

        it "does not create a new build if the latest commit already has a build" do
          FactoryGirl.create(:build, :state => :errored, :project => project, :branch => "master", :ref => branch_head_sha)
          GitRepo.stub(:sha_for_branch).and_return(branch_head_sha)

          expect do
            post @action, {:project_id => project.to_param}
          end.to_not change { Build.count }
          flash[:error].should be_nil
          flash[:warn].should be_present
        end
      end

      it "doesn't create a build if no branch is given" do
        expect {
          post @action, {:project_id => project.to_param, :build => {:branch => nil}}
        }.to_not change { Build.count }
      end

      context "ref already exits" do
        let!(:build) { FactoryGirl.create(:build, :state => :succeeded, :project => project, :branch => branch, :ref => branch_head_sha) }

        it "doesn't create a build" do
          expect do
            post @action, {:project_id => project.to_param, :build => {:branch => branch}}
          end.to_not change { Build.count }
          flash[:error].should be_nil
          flash[:warn].should be_present
        end
      end

      context "when github returns a 404" do
        it "throws not found exception" do
          stub_request(:get, "https://api.github.com/repos/square/#{project.repository.repository_name}/git/refs/heads/#{branch}").to_return(:status => 200, :body => '{"message": "Not Found"}')
          expect do
            post @action, {:project_id => project.to_param, :build => {:branch => branch}}
          end.to_not change { Build.count }
        end
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

  describe "#toggle_merge_on_success" do
    before do
      @build = FactoryGirl.create(:build, :merge_on_success => true)
    end

    it "aborts merge_on_success" do
      post :toggle_merge_on_success, :id => @build.id, :project_id => @build.project.name, :merge_on_success => false
      response.should redirect_to(project_build_path(@build.project, @build))
      @build.reload.merge_on_success.should be_false
    end

    it "enables merge_on_success" do
      @build.update_attributes(:merge_on_success => false)
      post :toggle_merge_on_success, :id => @build.id, :project_id => @build.project.name, :merge_on_success => true
      response.should redirect_to(project_build_path(@build.project, @build))
      @build.reload.merge_on_success.should be_true
    end
  end

  describe "merge_on_success checkbox" do
    render_views
    let(:project) { FactoryGirl.create(:project) }
    let(:build) { FactoryGirl.create(:build, :project => project) }
    before do
      @action = :show
      @params = {:id => build.id, :project_id => project.name}
    end

    it "renders the merge_on_success checkbox" do
      get @action, @params
      doc = Nokogiri::HTML(response.body)
      elements = doc.css("input[name=merge_on_success]")
      elements.size.should == 1
      elements.first['checked'].should be_blank
    end

    context "for builds with merge_on_success enabled" do
      let(:build) { FactoryGirl.create(:build, :project => project, :merge_on_success => true) }
      it "renders the merge_on_success checkbox" do
        get @action, @params
        doc = Nokogiri::HTML(response.body)
        elements = doc.css("input[name=merge_on_success]")
        elements.size.should == 1
        elements.first['checked'].should be_present
      end
    end

    context "for master builds" do
      let(:repository) { FactoryGirl.create(:repository, :url => "git@github.com:org/test-repo.git") }
      let(:project) { FactoryGirl.create(:project, :repository => repository, :name => repository.repository_name) }

      it "renders the merge_on_success checkbox disabled" do
        get @action, @params
        doc = Nokogiri::HTML(response.body)
        elements = doc.css("input[name=merge_on_success]")
        elements.size.should == 1
        elements.first['disabled'].should be_present
      end
    end
  end

  describe "#rebuild_failed_parts" do
    let(:build) { FactoryGirl.create(:build) }
    let(:parts) { (1..4).map { FactoryGirl.create(:build_part, :build_instance => build) } }

    subject { post :rebuild_failed_parts, :project_id => build.project.to_param, :id => build.id }

    context "happy path" do
      before do
        @attempt_1 = FactoryGirl.create(:build_attempt, :build_part => parts[0], :state => :failed)
        @attempt_2 = FactoryGirl.create(:build_attempt, :build_part => parts[1], :state => :failed)
        @attempt_3 = FactoryGirl.create(:build_attempt, :build_part => parts[1], :state => :errored)
        @attempt_4 = FactoryGirl.create(:build_attempt, :build_part => parts[2], :state => :passed)
        @attempt_5 = FactoryGirl.create(:build_attempt, :build_part => parts[3], :state => :aborted)
      end

      it "rebuilds all failed attempts" do
        build.build_parts.failed_errored_or_aborted.count.should == 3
        subject
        build.reload.build_parts.failed.count.should be_zero
        build.build_attempts.count.should == 5 + 3
      end

      it "only enqueues one build attempt for each failed build part" do
        subject
        parts[0].reload.build_attempts.count.should == 2
        parts[1].reload.build_attempts.count.should == 3
        parts[3].reload.build_attempts.count.should == 2

        expect {
          # repost to test idempotency
          post :rebuild_failed_parts, :project_id => build.project.to_param, :id => build.id
        }.to_not change(BuildAttempt, :count)
      end
    end

    context "an successful prior build attempt should not be rebuilt" do
      it "does something" do
        FactoryGirl.create(:build_attempt, :build_part => parts[1], :state => :passed) # attempt 1
        FactoryGirl.create(:build_attempt, :build_part => parts[1], :state => :failed) # attempt 2

        expect { subject }.to_not change(BuildAttempt, :count)
      end
    end
  end
end
