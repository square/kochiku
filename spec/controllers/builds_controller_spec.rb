require 'spec_helper'

describe BuildsController do
  describe "#create" do
    let(:action) { :create }
    let(:repo) { FactoryGirl.create(:repository) }
    let!(:branch) { FactoryGirl.create(:branch, repository: repo, name: 'gummy-bears') }
    let(:git_sha) { '30b111147d9a245468c6650f54de5c16584bc154' }
    let(:params) {
      {
        repo_url: repo.url,
        git_branch: branch.name,
        git_sha: git_sha,
      }
    }

    it "should return a 404 if the repo does not exist" do
      repo.destroy
      post action, params
      expect(response.code).to eq("404")
    end

    it "should create a branch record if it does not exist" do
      branch_name = branch.name
      branch.destroy
      expect {
        post action, params
      }.to change { Branch.exists?(name: branch_name) }.from(false).to(true)
    end

    it "should create a new build" do
      expect {
        post action, params
      }.to change { Build.exists?(ref: git_sha) }.from(false).to(true)
    end

    it "sets merge_on_success when param given" do
      post action, params.merge(merge_on_success: "1")
      new_build = Build.where(ref: git_sha).first
      expect(new_build.merge_on_success).to be(true)
    end

    it "defaults merge_on_success to false when param not given" do
      expect(params.key?(:merge_on_success)).to be(false)
      post action, params
      new_build = Build.where(ref: git_sha).first
      expect(new_build.merge_on_success).to be(false)
    end

    it "should return the build info page in the location header" do
      post action, params

      new_build = Build.where(ref: git_sha).first
      expect(new_build).to be_present

      expect(response.location).to eq(repository_build_url(repo, new_build))
    end

    context "a specific git_sha is not specified" do
      let(:params) {
        {
          repo_url: repo.url,
          git_branch: branch.name,
        }
      }

      before do
        mocked_remote_server = RemoteServer.for_url(repo.url)
        allow(mocked_remote_server).to receive(:sha_for_branch).with(branch.name).and_return(to_40("2"))
        allow(RemoteServer).to receive(:for_url).with(repo.url).and_return(mocked_remote_server)
      end

      it "should create a build for the HEAD commit on the given branch" do
        expect {
          post action, params
        }.to change { Build.exists?(ref: to_40("2"), branch_record: branch) }.from(false).to(true)
      end
    end

    context "when the pushed sha has already been built" do
      it "has no effect" do
        branch = FactoryGirl.create(:branch, repository: repo, name: 'other-branch')
        build = FactoryGirl.create(:build, branch_record: branch, ref: git_sha)
        expect {
          post action, params
          expect(response).to be_success
        }.to_not change(Build, :count)
        expect(response.headers["Location"]).to eq(repository_build_url(repo, build))
      end
    end

    context "when the sha is already associated with another branch under this repo" do
      it "should return a URL to the existing build" do
        other_branch = FactoryGirl.create(:branch, repository: repo)
        other_build = FactoryGirl.create(:build, branch_record: other_branch, ref: git_sha)
        branch  # ensure the 'let' gets invoked

        post action, params
        expect(response).to be_success
        expect(response.headers["Location"]).to eq(repository_build_url(repo, other_build))
      end
    end

    context "when the sha is already used by a different repo" do
      it "should create a new build" do
        other_repo = FactoryGirl.create(:repository)
        other_branch = FactoryGirl.create(:branch, repository: other_repo)
        other_build = FactoryGirl.create(:build, branch_record: other_branch, ref: git_sha)

        expect {
          post action, params
          expect(response).to be_success
        }.to change(Build, :count).by(1)
        expect(response.headers["Location"]).to_not eq(repository_build_url(other_repo, other_build))
      end
    end

    it "should allow the repository url to be in an alternate format" do
      expect(repo).to_not be_new_record

      post action, params.merge(repo_url: "https://github.com/#{repo.namespace}/#{repo.name}.git")
      expect(response).to be_success
    end
  end

  describe "#show" do
    it "should return a valid JSON" do
      branch = FactoryGirl.create(:branch, name: 'gummy-bears')
      build = FactoryGirl.create(:build, branch_record: branch)
      build_part = FactoryGirl.create(:build_part, build_instance: build)
      FactoryGirl.create(:build_attempt, :build_part => build_part, :state => :passed)
      get :show, repository_path: branch.repository, id: build.id, format: :json
      ret = JSON.parse(response.body)
      expect(ret['build']['build_parts'].length).to eq(1)
      expect(ret['build']['build_parts'][0]['build_id']).to eq(build.id)
      expect(ret['build']['build_parts'][0]['status']).to eq('passed')
    end

    context "when the repository is disabled" do
      render_views
      let(:build) {
        FactoryGirl.create(:build_on_disabled_repo, state: :failed)
      }

      it "should not show 'Rebuild failed parts' button or rebuild action in #build-summary table" do
        build_part = FactoryGirl.create(:build_part, build_instance: build)
        FactoryGirl.create(:completed_build_attempt, build_part: build_part, state: :failed)
        get :show, repository_path: build.repository, id: build.id
        expect(response.body).to_not match(/<input.*value="Rebuild failed parts"/)
        expect(response.body).to_not match(%r{<a.*>Rebuild<\/a>$})
      end

      it "should not show 'Retry Partitioning' button" do
        build.build_parts.delete_all
        get :show, repository_path: build.repository, id: build.id
        expect(response.body).to_not match(/<input.*value="Retry Partitioning"/)
      end
    end

    context "when the repository is enabled" do
      render_views
      let(:build) {
        FactoryGirl.create(:build, state: :failed)
      }

      it "should show 'Rebuild failed parts' button or rebuild action in #build-summary table" do
        build_part = FactoryGirl.create(:build_part, build_instance: build)
        FactoryGirl.create(:completed_build_attempt, build_part: build_part, state: :failed)
        get :show, repository_path: build.repository, id: build.id
        expect(response.body).to match(/<input.*value="Rebuild failed parts"/)
        expect(response.body).to match(%r{<a.*>Rebuild<\/a>$})
      end

      it "should show 'Retry Partitioning' button" do
        build.build_parts.delete_all
        get :show, repository_path: build.repository.to_param, id: build.id
        expect(response.body).to match(/<input.*value="Retry Partitioning"/)
      end
    end
  end

  describe "#abort" do
    before do
      @build = FactoryGirl.create(:build)
      put :abort, repository_path: @build.repository.to_param, id: @build.to_param
    end

    it "redirects back to the build page" do
      expect(response).to redirect_to(repository_build_path(@build.repository, @build))
    end

    # spot-check that it does some abort action
    it "sets the build's state to aborted" do
      expect(@build.reload.state).to eq(:aborted)
    end
  end

  describe "#on_success_log_file link" do
    render_views
    let(:build) { FactoryGirl.create(:build, state: :succeeded) }
    before do
      @action = :show
      @params = {:id => build.id, :repository_path => build.repository}
    end

    context "has on_success_log_file" do
      before do
        output = "Exited with status: 0"
        script_log = FilelessIO.new(output)
        script_log.original_filename = "on_success_script.log"
        build.on_success_script_log_file = script_log
        build.save
      end

      it "displays link to on_success_log_file" do
        get @action, @params
        doc = Nokogiri::HTML(response.body)
        elements = doc.search("[text()*='on_success_script.log']")
        expect(elements.size).to eq(1)
      end
    end

    context "does not have on_success_log_file" do
      it "does not display link to on_success_log_file" do
        get @action, @params
        doc = Nokogiri::HTML(response.body)
        elements = doc.search("[text()*='on_success_script.log']")
        expect(elements.size).to eq(0)
      end
    end
  end

  describe "#toggle_merge_on_success" do
    before do
      @build = FactoryGirl.create(:build, :merge_on_success => true)
    end

    it "aborts merge_on_success" do
      post :toggle_merge_on_success, id: @build.to_param, repository_path: @build.repository.to_param, merge_on_success: false
      expect(response).to redirect_to(repository_build_path(@build.repository, @build))
      expect(@build.reload.merge_on_success).to be false
    end

    it "enables merge_on_success" do
      @build.update_attributes(:merge_on_success => false)
      post :toggle_merge_on_success, id: @build.to_param, repository_path: @build.repository.to_param, merge_on_success: true
      expect(response).to redirect_to(repository_build_path(@build.repository, @build))
      expect(@build.reload.merge_on_success).to be true
    end
  end

  describe "merge_on_success checkbox" do
    render_views
    let(:build) { FactoryGirl.create(:build) }

    before do
      @action = :show
      @params = {:id => build.id, :repository_path => build.repository}
    end

    it "renders the merge_on_success checkbox" do
      get @action, @params
      doc = Nokogiri::HTML(response.body)
      elements = doc.css("input[name=merge_on_success]")
      expect(elements.size).to eq(1)
      expect(elements.first['checked']).to be_blank
    end

    context "for builds with merge_on_success enabled" do
      let(:build) { FactoryGirl.create(:build, merge_on_success: true) }
      it "renders the merge_on_success checkbox" do
        get @action, @params
        doc = Nokogiri::HTML(response.body)
        elements = doc.css("input[name=merge_on_success]")
        expect(elements.size).to eq(1)
        expect(elements.first['checked']).to be_present
      end
    end

    context "for builds on a convergence branch" do
      let(:build) { FactoryGirl.create(:convergence_branch_build) }

      it "renders the merge_on_success checkbox disabled" do
        get @action, @params
        doc = Nokogiri::HTML(response.body)
        elements = doc.css("input[name=merge_on_success]")
        expect(elements.size).to eq(1)
        expect(elements.first['disabled']).to be_present
      end
    end
  end

  describe "#rebuild_failed_parts" do
    let(:build) { FactoryGirl.create(:build) }
    let(:parts) { (1..4).map { FactoryGirl.create(:build_part, :build_instance => build) } }

    before do
      allow(GitRepo).to receive(:load_kochiku_yml).and_return(nil)
    end

    subject { post :rebuild_failed_parts, repository_path: build.repository.to_param, id: build.id }

    context "happy path" do
      before do
        @attempt_1 = FactoryGirl.create(:build_attempt, :build_part => parts[0], :state => :failed)
        @attempt_2 = FactoryGirl.create(:build_attempt, :build_part => parts[1], :state => :failed)
        @attempt_3 = FactoryGirl.create(:build_attempt, :build_part => parts[1], :state => :errored)
        @attempt_4 = FactoryGirl.create(:build_attempt, :build_part => parts[2], :state => :passed)
        @attempt_5 = FactoryGirl.create(:build_attempt, :build_part => parts[3], :state => :aborted)
      end

      it "rebuilds all failed attempts" do
        expect(build.build_parts.failed_errored_or_aborted.count).to eq(3)
        subject
        expect(build.reload.build_parts.failed.count).to be_zero
        expect(build.build_attempts.count).to eq(5 + 3)
      end

      it "only enqueues one build attempt for each failed build part" do
        subject
        expect(parts[0].reload.build_attempts.count).to eq(2)
        expect(parts[1].reload.build_attempts.count).to eq(3)
        expect(parts[3].reload.build_attempts.count).to eq(2)

        expect {
          # repost to test idempotency
          post :rebuild_failed_parts, repository_path: build.repository.to_param, id: build.id
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

  describe "#retry_partitioning" do
    let(:build) { FactoryGirl.create(:build) }
    before do
      allow(GitRepo).to receive(:load_kochiku_yml).and_return(nil)
    end

    context "when there are no build parts" do
      it "enques a partitioning job" do
        expect(Resque).to receive(:enqueue)
        post :retry_partitioning, repository_path: build.repository.to_param, id: build.id
        expect(response).to redirect_to(repository_build_path(build.repository, build))
      end
    end

    context "when there are already build parts" do
      it "does nothing" do
        expect(Resque).to_not receive(:enqueue)
        FactoryGirl.create(:build_part, build_instance: build)
        post :retry_partitioning, repository_path: build.repository.to_param, id: build.id
        expect(response).to redirect_to(repository_build_path(build.repository, build))
      end
    end

    context "when the build's repository is disabled" do
      it "should not partition build" do
        build2 = FactoryGirl.create(:build_on_disabled_repo)
        expect(Resque).to_not receive(:enqueue)
        post :retry_partitioning, repository_path: build2.repository.to_param, id: build2.id
        expect(response).to redirect_to(repository_build_path(build2.repository, build2))
      end
    end
  end

  describe "#build_redirect" do
    it "should redirect to the full build show url" do
      build = FactoryGirl.create(:build)
      get :build_redirect, id: build.id
      expect(response).to redirect_to(repository_build_path(build.repository, build))
    end
  end

  describe "#build_ref_redirect" do
    it "should redirect to the build show url that matches the ref given" do
      build = FactoryGirl.create(:build)
      get :build_ref_redirect, ref: build.ref[0,8]
      expect(response).to redirect_to(repository_build_path(build.repository, build))
    end
  end
end
