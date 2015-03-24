require 'spec_helper'

describe Repository do
  before do
    settings = SettingsAccessor.new(<<-YAML)
    git_servers:
      stash.example.com:
        type: stash
      git.example.com:
        type: github
        aliases:
          - git-alias.example.com
      github.com:
        type: github
    YAML
    stub_const "Settings", settings
  end

  describe '.lookup_by_url' do
    it 'should return the Repository (straightforward)' do
      repo = FactoryGirl.create(:repository)
      expect(Repository.lookup_by_url(repo.url)).to eq(repo)
    end

    it 'should return the Repository when a host alias is used during creation' do
      repo = FactoryGirl.create(:repository, url: "git@git-alias.example.com:square/some-repo.git")
      expect(Repository.lookup_by_url("git@git.example.com:square/some-repo.git")).to eq(repo)
    end

    it 'should return the Repository when a host alias is used during lookup' do
      repo = FactoryGirl.create(:repository, url: "git@git.example.com:square/some-repo.git")
      expect(Repository.lookup_by_url("git@git-alias.example.com:square/some-repo.git")).to eq(repo)
    end

    it 'should return nil if lookup fails' do
      expect(
        Repository.lookup_by_url("git@git-alias.example.com:square/some-repo.git")
      ).to be_nil
    end
  end

  describe 'creation' do
    it 'should extract attributes from the url' do
      repo = Repository.new(url: "git://git.example.com/who/what.git")
      expect(repo.host).to eq('git.example.com')
      expect(repo.namespace).to eq('who')
      expect(repo.name).to eq('what')
    end

    it 'should not allow url to trump explicit values' do
      repo = Repository.new(name: 'explicit_name',
                            namespace: 'explicit_namespace',
                            host: 'git-alias.example.com')
      repo.url = "git://git.example.com/who/what.git"
      expect(repo.name).to eq('explicit_name')
      expect(repo.namespace).to eq('explicit_namespace')
      expect(repo.host).to eq('git-alias.example.com')
    end
  end

  describe 'validations' do

    context 'for url' do
      it "should add a error on url, if url is an an unsupported format" do
        repo = Repository.new(url: "file://data/git/fun-proj.git")
        expect(repo).to have(1).error_on(:url)
        expect(repo.errors_on(:url)).to include("is not in a format supported by Kochiku")
      end

    end

    context "when name" do
      context "is set" do
        it "leaves it as is" do
          repo = Repository.new(url: "git://git.example.com/square/kochiku-name.git",
              name: "another_project")
          repo.valid?
          expect(repo.name).to eq("another_project")
        end
      end

      context "is not set when saving" do
        it "sets the name based on the repository url" do
          repo = Repository.new(url: "git://git.example.com/square/kochiku-name.git")
          repo.valid?
          expect(repo.name).to eq("kochiku-name")
        end

        context "when that name already exists" do
          let!(:existing_repo) { FactoryGirl.create(:repository, name: 'my-repo') }

          it "does not validate" do
            repo = FactoryGirl.build(:repository, name: 'my-repo')
            expect(repo).to_not be_valid
          end
        end
      end
    end

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
        repository.projects.create name: repository.name
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

  describe '#build_for_commit' do
    let!(:repositoryA) { FactoryGirl.create(:repository) }
    let!(:projectA1) { FactoryGirl.create(:project, repository: repositoryA) }
    let!(:repositoryB) { FactoryGirl.create(:repository) }
    let!(:buildA1) { FactoryGirl.create(:build, project: projectA1, ref: sha) }
    let(:sha) { to_40('a') }

    context 'a build for the sha exists under this repository' do
      it 'should return an existing build with the same sha' do
        expect(repositoryA.build_for_commit(sha)).to eq(buildA1)
      end
    end

    context 'a build exists under a different repository' do
      it 'should return nil' do
        expect(repositoryB.build_for_commit(sha)).to be_nil
      end
    end
  end
end
