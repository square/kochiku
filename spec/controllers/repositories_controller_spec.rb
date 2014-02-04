require 'spec_helper'

describe RepositoriesController do
  render_views
  describe "create action" do
    it "should perform a basic create" do
      expect{
        post :create, :repository => {:url => "git@git.example.com:square/kochiku.git", :test_command => "script/something"}
        expect(response).to be_redirect
      }.to change(Repository, :count).by(1)
      repository = Repository.where(url: "git@git.example.com:square/kochiku.git").first
      expect(repository).to be_present
      expect(repository.test_command).to eq("script/something")
    end

    it "creates a ci project" do
      expect{
        post :create, :repository => {:url => "git@git.example.com:square/kochiku.git", :test_command => "script/something"}
        expect(response).to be_redirect
      }.to change(Project, :count).by(2)
      repository = Repository.where(url: "git@git.example.com:square/kochiku.git").first
      expect(repository.projects.size).to eq(2)
      expect(repository.projects.map(&:name).sort).to eq(["kochiku", "kochiku-pull_requests"])
    end

    context "with repository name" do
      it "creates a project with the specified name" do
        expect{
          post :create, :repository => {url: "git@git.example.com:square/kochiku.git",
              test_command: "script/something", repository_name: "a-project-name"}
          expect(response).to be_redirect
        }.to change(Project, :count).by(2)
        repository = Repository.where(url: "git@git.example.com:square/kochiku.git").first
        expect(repository.projects.size).to eq(2)
        expect(repository.projects.map(&:name).sort).to eq(["a-project-name", "a-project-name-pull_requests"])
      end
    end

    context "with validation errors" do
      let(:params) { { url: '' } }

      it "re-renders form with errors" do
        post :create, repository: params
        expect(response).to be_success
        expect(assigns[:repository].errors.full_messages.join(',')).
          to include("Url can't be blank")
        expect(response).to render_template('new')
      end
    end
  end

  describe "get /repositories/:id/projects" do
    let!(:repository) { FactoryGirl.create(:repository)}
    let!(:project) { FactoryGirl.create(:project, :repository => repository)}
    let!(:project2) { FactoryGirl.create(:project)}
    it "shows only a repositories projects" do
      get :projects, :id => repository.id
      expect(response).to be_success
      doc = Nokogiri::HTML(response.body)
      elements = doc.css(".projects .build-info")
      expect(elements.size).to eq(1)
    end
  end

  describe "update" do
    let!(:repository) { FactoryGirl.create(:repository, :url => "git@git.example.com:square/kochiku.git", :test_command => "script/something")}

    it "updates existing repository" do
      expect{
        patch :update, :id => repository.id, :repository => {:url => "git@git.example.com:square/kochiku-worker.git", :test_command => "script/something-else"}
        expect(response).to be_redirect
      }.to_not change(Repository, :count)
      repository.reload
      expect(repository.url).to eq("git@git.example.com:square/kochiku-worker.git")
      expect(repository.test_command).to eq("script/something-else")
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
      :run_ci,
      :use_branches_on_green,
      :build_pull_requests,
      :send_build_failure_email,
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
      :url,
      :test_command,
      :on_green_update,
      :command_flag,
      :on_success_script,
      :on_success_note,
      :repository_name
    ].each do |attribute|
      it "should successfully update the #{attribute} attribute" do
        new_value = "Keytar Intelligentsia artisan typewriter 3 wolf moon"
        patch :update, id: repository.id, repository: { attribute => new_value }
        repository.reload
        expect(repository.send(attribute)).to eq(new_value)
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

  describe "get /repositories/:id/edit" do
    it "responds with success" do
      get :edit, :id => FactoryGirl.create(:repository).id
      expect(response).to be_success
    end
  end

  describe "get /repositories/new" do
    it "responds with success" do
      get :new
      expect(response).to be_success
    end
  end

  describe 'post /build-ref' do
    let(:repository) { FactoryGirl.create(:repository) }
    let(:repo_name) { repository.repository_name }

    it "creates a master build with query string parameters" do
      post :build_ref, id: repository.to_param, ref: 'master', sha: 'abc123'

      verify_response_creates_build response, 'master', 'abc123', repo_name
    end

    it "creates a master build with payload" do
      post :build_ref, id: repository.to_param, refChanges: [{refId: 'refs/head/master', toHash: 'abc123'}]

      verify_response_creates_build response, 'master', 'abc123', repo_name
    end

    it "creates a PR build with query string parameters" do
      post :build_ref, id: repository.to_param, ref: 'blah', sha: 'abc123'

      verify_response_creates_build response, 'blah', 'abc123', repo_name + "-pull_requests"
    end

    it "creates a PR build with payload" do
      post :build_ref, id: repository.to_param, refChanges: [{refId: 'refs/head/blah', toHash: 'abc123'}]

      verify_response_creates_build response, 'blah', 'abc123', repo_name + "-pull_requests"
    end

    def verify_response_creates_build(response, branch, ref, repo_name)
      expect(response).to be_success
      json       = JSON.parse(response.body)
      build_hash = json['builds'][0]
      build      = Build.find(build_hash['id'])

      expect(build_hash['build_url']).not_to be_nil

      expect(build.branch).to eq(branch)
      expect(build.ref).to eq(ref)
      expect(build.project.name).to eq(repo_name)
    end
  end
end
