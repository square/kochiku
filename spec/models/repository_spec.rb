require 'spec_helper'

describe Repository do
  before do
    settings = SettingsAccessor.new(<<-YAML)
    git_servers:
      stash.example.com:
        type: stash
      git.example.com:
        type: github
      github.com:
        type: github
    YAML
    stub_const "Settings", settings
  end

  describe '#main_project' do
    let(:repository) { project.repository }
    let(:project) { FactoryGirl.create :project }
    subject { repository.main_project }

    context 'without a main project' do
      it 'returns nil' do
        expect(subject).to be_nil
      end
    end

    context 'with a matching main project name' do
      let!(:main_project) do
        repository.projects.create name: repository.repository_name
      end

      it 'returns the main project' do
        expect(subject).to eq(main_project)
      end
    end
  end

  context "#interested_github_events" do
    it 'includes push if run_ci is enabled' do
      expect(Repository.new(:run_ci => true).interested_github_events).to eq(['pull_request', 'push'])
    end
    it 'does not include push if run_ci is enabled' do
      expect(Repository.new(:run_ci => false).interested_github_events).to eq(['pull_request'])
    end
  end

  context "#promotion_refs" do
    it "is an empty array when promotion_refs is a empty string" do
      expect(Repository.new(:on_green_update => "").promotion_refs).to eq([])
    end

    it "is an empty array when promotion_refs is a blank string" do
      expect(Repository.new(:on_green_update => "   ").promotion_refs).to eq([])
    end

    it "is an empty array when promotion_refs is comma" do
      expect(Repository.new(:on_green_update => "  , ").promotion_refs).to eq([])
    end

    it "splits on comma's" do
      expect(Repository.new(:on_green_update => "a,b,c").promotion_refs).to eq(["a", "b", "c"])
    end
  end

  context "#base_api_url" do
    it "handles ssh urls" do
      repo = Repository.new(url: "git@git.example.com:square/kochiku.git")
      expect(repo.base_api_url).to eq("https://git.example.com/api/v3/repos/square/kochiku")
    end
  end

  context "#base_html_url" do
    it "handles ssh urls" do
      repo = Repository.new(url: "git@git.example.com:square/kochiku.git")
      expect(repo.base_html_url).to eq("https://git.example.com/square/kochiku")
    end
    it "handles http urls" do
      repo = Repository.new(url: "http://git.example.com/square/kochiku.git")
      expect(repo.base_html_url).to eq("https://git.example.com/square/kochiku")
    end
    it "handles https urls" do
      repo = Repository.new(url: "https://git.example.com/square/kochiku.git")
      expect(repo.base_html_url).to eq("https://git.example.com/square/kochiku")
    end
    it "handles git read only urls" do
      repo = Repository.new(url: "git://git.example.com/square/kochiku.git")
      expect(repo.base_html_url).to eq("https://git.example.com/square/kochiku")
    end
  end

  context "#repository_name" do
    context "respository_name is set" do
      it "returns the value" do
        repo = Repository.new(url: "git://git.example.com/square/kochiku-name.git",
            repository_name: "another_project")
        repo.save
        repo.reload
        expect(repo.repository_name).to eq("another_project")
      end
    end

    context "repository_name is not set when saving" do
      it "sets the repository name based on the repository url" do
        repo = Repository.new(url: "git://git.example.com/square/kochiku-name.git")
        repo.save
        repo.reload
        expect(repo.repository_name).to eq("kochiku-name")
      end

      context "when that name already exists" do
        let!(:existing_repo) { FactoryGirl.create(:repository, repository_name: 'my-repo') }

        it "does not validate" do
          repo = FactoryGirl.build(:repository, repository_name: 'my-repo')
          expect(repo).to_not be_valid
        end
      end
    end

    context "without url" do
      let(:repository) { Repository.new(url: '') }

      it "gives validation error without blowing up" do
        expect(repository).to_not be_valid
        expect(repository).to have(1).errors_on (:url)
      end
    end
  end

  context "with stash repository" do
    before do
      allow(Settings).to receive(:stash_host).and_return('stash.example.com')
    end

    let(:repo) {
      Repository.new(url: "https://stash.example.com/scm/myproject/myrepo.git").tap(&:valid?)
    }

    context "#repository_name" do
      it "returns the repositories name" do
        expect(repo.repository_name).to eq("myrepo")
      end
    end

    context '.project_params' do
      it 'parses out pertinent information' do
        expect(repo.project_params).to eq(
          host:       'stash.example.com',
          username:   'myproject',
          repository: 'myrepo'
        )
      end
    end
  end

  context "#repo_cache_name" do
    it "returns the cache from the settings or the default from the repo name" do
      repository = Repository.new(:repo_cache_dir => "foobar")
      expect(repository.repo_cache_name).to eq("foobar")
    end

    it "returns the cache from the settings or the default from the repo name" do
      repository = Repository.new(url: "https://git.example.com/square/kochiku")
      repository.valid?
      expect(repository.repo_cache_name).to eq("kochiku-cache")
    end
  end

  context "#run_ci=" do
    it "converts the checkbox to bool" do
      repository = FactoryGirl.create(:repository)
      repository.run_ci="1"
      repository.save
      repository.reload
      expect(repository.run_ci).to eq(true)
      repository.run_ci="0"
      repository.save
      repository.reload
      expect(repository.run_ci).to eq(false)
    end
  end

  context "#build_pull_requests=" do
    it "converts the checkbox to bool" do
      repository = FactoryGirl.create(:repository)
      repository.build_pull_requests="1"
      repository.save
      repository.reload
      expect(repository.build_pull_requests).to eq(true)
      repository.build_pull_requests="0"
      repository.save
      repository.reload
      expect(repository.build_pull_requests).to eq(false)
    end
  end

  it "saves build tags" do
    repository = FactoryGirl.create(:repository)
    repository.on_green_update="1,2,3"
    repository.save
    repository.reload
    expect(repository.on_green_update).to eq("1,2,3")
  end

  context "has_on_success_script?" do
    it "is false if the script is blank" do
      expect(Repository.new(:on_success_script => "").has_on_success_script?).to be false
      expect(Repository.new(:on_success_script => nil).has_on_success_script?).to be false
      expect(Repository.new(:on_success_script => "  ").has_on_success_script?).to be false
      expect(Repository.new(:on_success_script => " \n ").has_on_success_script?).to be false
    end

    it "is true if there is a script" do
      expect(Repository.new(:on_success_script => "hi").has_on_success_script?).to be true
    end
  end

  describe '.canonical_repository_url' do

    context 'a github url' do
      it 'should return a ssh url when given a https url' do
        result = Repository.canonical_repository_url("https://github.com/square/test-repo1.git")
        expect(result).to eq("git@github.com:square/test-repo1.git")
      end

      it 'should do nothing when given a ssh url' do
        ssh_url = "git@github.com:square/test-repo1.git"
        result = Repository.canonical_repository_url(ssh_url)
        expect(result).to eq(ssh_url)
      end
    end

    context 'a stash url' do
      it 'should return a https url when given a ssh url' do
        result = Repository.canonical_repository_url("ssh://git@stash.example.com:7999/foo/bar.git")
        expect(result).to eq("https://stash.example.com/scm/foo/bar.git")
      end

      it 'should do nothing when given a https url' do
        https_url = "https://stash.example.com/scm/foo/bar.git"
        result = Repository.canonical_repository_url(https_url)
        expect(result).to eq(https_url)
      end
    end

  end
end
