require 'spec_helper'

describe RepositoriesController do
  render_views
  describe "create action" do
    before do
      @params = {
        repository: { url: "git@git.example.com:square/kochiku.git", test_command: "script/something" },
        convergence_branches: "",
      }
    end
    it "should perform a basic create" do
      expect{
        post :create, @params
        expect(response).to be_redirect
      }.to change(Repository, :count).by(1)
      repository = Repository.where(url: "git@git.example.com:square/kochiku.git").first
      expect(repository).to be_present
      expect(repository.name).to eq('kochiku')
    end

    it "sets host, namespace, and name based on the repo url" do
      post :create, @params
      repository = Repository.where(url: "git@git.example.com:square/kochiku.git").first
      expect(repository.host).to eq('git.example.com')
      expect(repository.namespace).to eq('square')
      expect(repository.name).to eq('kochiku')
    end

    it "creates a branch_record for the convergence branches" do
      post :create, @params.merge(convergence_branches: "master, release-1-x")
      expect(response).to be_redirect
      expect(Branch.exists?(name: 'master', convergence: true)).to be(true)
      expect(Branch.exists?(name: 'release-1-x', convergence: true)).to be(true)
    end

    context "with validation errors" do
      it "re-renders form with errors" do
        # timeout outside of the allowable range
        @params[:repository][:timeout] = '1000000'

        post :create, @params
        expect(response).to be_success
        expect(assigns[:repository].errors.full_messages.join(','))
          .to include("The maximum timeout allowed is 1440 minutes")
        expect(response).to render_template('new')
      end
    end
  end

  describe "update" do
    let!(:repository) { FactoryGirl.create(:repository, :url => "git@git.example.com:square/kochiku.git")}

    it "updates existing repository" do
      expect{
        patch :update, :id => repository.id, :repository => {:url => "git@git.example.com:square/kochiku-worker.git"}
        expect(response).to be_redirect
      }.to_not change(Repository, :count)
      repository.reload
      expect(repository.url).to eq("git@git.example.com:square/kochiku-worker.git")
      expect(response).to be_redirect
    end

    context "with invalid data" do
      let(:params) { { timeout: 'abc' } }

      it "re-renders the edit page" do
        patch :update, id: repository.id, repository: params
        expect(response).to be_success
        expect(response).to render_template('edit')
      end
    end

    # boolean attributes
    [
      :enabled,
      :run_ci,
      :build_pull_requests,
      :send_build_failure_email,
      :send_build_success_email,
      :send_merge_successful_email,
      :allows_kochiku_merges
    ].each do |attribute|
      it "should successfully update the #{attribute} attribute" do
        start_value = repository.send(attribute)
        inverse_value_as_str = start_value ? "0" : "1"
        patch :update, id: repository.id, repository: { attribute => inverse_value_as_str }
        repository.reload
        expect(repository.send(attribute)).to eq(!start_value)
      end
    end

    # integer attributes
    [:timeout].each do |attribute|
      it "should successfully update the #{attribute} attribute" do
        new_value = rand(1440) # max imposed by repository validation
        patch :update, id: repository.id, repository: { attribute => new_value }
        repository.reload
        expect(repository.send(attribute)).to eq(new_value)
      end
    end

    # string attributes
    [
      :on_green_update,
    ].each do |attribute|
      it "should successfully update the #{attribute} attribute" do
        new_value = "Keytar Intelligentsia artisan typewriter 3 wolf moon"
        patch :update, id: repository.id, repository: { attribute => new_value }
        repository.reload
        expect(repository.send(attribute)).to eq(new_value)
      end
    end

    describe "of convergence branches" do
      it "should set convergence on new branches in the list" do
        # branchA already has convergence
        branchA = FactoryGirl.create(:branch, repository: repository, name: 'branchA', convergence: true)
        # branchB does not have convergence
        branchB = FactoryGirl.create(:branch, repository: repository, name: 'branchB', convergence: false)
        # branchC does not have convergence
        branchC = FactoryGirl.create(:branch, repository: repository, name: 'branchC', convergence: false)
        # branchD does not yet exist

        patch :update, id: repository.id, repository: {timeout:10}, convergence_branches: "branchA,branchB,branchD"
        expect(branchA.reload).to be_convergence
        expect(branchB.reload).to be_convergence
        expect(branchC.reload).to_not be_convergence
        branchD = repository.branches.where(name: 'branchD').first!
        expect(branchD).to be_convergence
      end

      it "should remove convergence from branches no longer in the list" do
        # branchA has convergence
        branchA = FactoryGirl.create(:branch, repository: repository, name: 'branchA', convergence: true)
        # branchB has convergence
        branchB = FactoryGirl.create(:branch, repository: repository, name: 'branchB', convergence: true)
        # branchC does not have convergence
        branchC = FactoryGirl.create(:branch, repository: repository, name: 'branchC', convergence: false)

        patch :update, id: repository.id, repository: {timeout:10}, convergence_branches: "branchA"
        expect(branchA.reload).to be_convergence
        expect(branchB.reload).to_not be_convergence
        expect(branchC.reload).to_not be_convergence
      end
    end
  end

  describe "delete /repositories/:id" do
    let!(:repository) { FactoryGirl.create(:repository, :url => "git@git.example.com:square/kochiku.git", :test_command => "script/something")}
    it "responds with success" do
      expect {
        get :destroy, :id => repository.id
        expect(response).to be_redirect
      }.to change(Repository, :count).by(-1)
    end
  end

  describe "get /repositories" do
    it "responds with success" do
      get :index
      expect(response).to be_success
    end
  end

  describe "get /:namespace/:name/edit" do
    it "responds with success" do
      get :edit, repository_path: FactoryGirl.create(:repository).to_param
      expect(response).to be_success
    end
  end

  describe "get /repositories/new" do
    it "responds with success" do
      get :new
      expect(response).to be_success
    end
  end

  describe "get /dashboard" do
    let(:repository) { FactoryGirl.create(:repository) }
    let!(:master_branch) { FactoryGirl.create(:master_branch, repository: repository) }
    let!(:non_master_branch) { FactoryGirl.create(:branch, :name => 'feature-branch', repository: repository) }

    it "displays the build status of only the master branches" do
      get :dashboard
      expect(response).to be_success
      doc = Nokogiri::HTML(response.body)
      elements = doc.css(".projects .ci-build-info")
      expect(elements.size).to eq(1)
    end
  end

  describe 'post /build-ref' do
    let(:repository) { FactoryGirl.create(:repository) }
    let(:fake_sha) { to_40('1') }

    it "creates a master build with query string parameters" do
      post :build_ref, id: repository.id, ref: 'master', sha: fake_sha

      verify_response_creates_build response, 'master', fake_sha
    end

    it "creates a master build with payload" do
      post :build_ref, id: repository.id, refChanges: [{refId: 'refs/heads/master', toHash: fake_sha}]

      verify_response_creates_build response, 'master', fake_sha
    end

    it "creates a branch build with query string parameters" do
      post :build_ref, id: repository.id, ref: 'blah', sha: fake_sha

      verify_response_creates_build response, 'blah', fake_sha
    end

    it "creates a branch build with payload" do
      post :build_ref, id: repository.id, refChanges: [{refId: 'refs/heads/blah', toHash: fake_sha}]

      verify_response_creates_build response, 'blah', fake_sha
    end

    it "creates a branch build for a branch name with slashes" do
      post :build_ref, id: repository.id, refChanges: [{refId: 'refs/heads/blah/with/a/slash', toHash: fake_sha}]

      verify_response_creates_build response, 'blah/with/a/slash', fake_sha
    end

    def verify_response_creates_build(response, branch_name, ref)
      expect(response).to be_success
      json       = JSON.parse(response.body)
      build_hash = json['builds'][0]
      build      = Build.find(build_hash['id'])

      expect(build_hash['build_url']).not_to be_nil

      expect(build.branch_record.name).to eq(branch_name)
      expect(build.ref).to eq(ref)
    end

    context "a convergence branch" do
      let(:branch) { FactoryGirl.create(:convergence_branch, repository: repository) }

      it "should not abort previous in-progress builds" do
        earlier_build = FactoryGirl.create(:build, state: :runnable, branch_record: branch)

        post :build_ref, id: repository.id, ref: branch.name, sha: fake_sha
        expect(earlier_build.reload.state).to eq(:runnable)
      end
    end

    context "not a convergence branch" do
      let(:branch) { FactoryGirl.create(:branch, repository: repository) }

      it "should abort all previous in-progress builds" do
        earlier_build = FactoryGirl.create(:build, state: :runnable, branch_record: branch)

        post :build_ref, id: repository.id, ref: branch.name, sha: fake_sha
        expect(earlier_build.reload.state).to eq(:aborted)
      end
    end
  end
end
