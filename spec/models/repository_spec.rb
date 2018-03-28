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
      repo = FactoryBot.create(:repository)
      expect(Repository.lookup_by_url(repo.url)).to eq(repo)
    end

    it 'should return the Repository when a host alias is used during creation' do
      repo = FactoryBot.create(:repository, url: "git@git-alias.example.com:square/some-repo.git")
      expect(Repository.lookup_by_url("git@git.example.com:square/some-repo.git")).to eq(repo)
    end

    it 'should return the Repository when a host alias is used during lookup' do
      repo = FactoryBot.create(:repository, url: "git@git.example.com:square/some-repo.git")
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

      it "should add an error on url on unknown git server" do
        repo = Repository.new(url: "git@example.com:who/what.git")
        expect(repo).to have(1).error_on(:url)
        expect(repo.errors_on(:url)).to include("host is not in Kochiku's list of git servers")
      end
    end

    context "when name" do
      context "is set" do
        it "leaves it as is" do
          repo = Repository.new(url: "git://git.example.com/square/kochiku-name.git",
                                name: "another_repo")
          repo.valid?
          expect(repo.name).to eq("another_repo")
        end
      end

      context "is not set when saving" do
        it "sets the name based on the repository url" do
          repo = Repository.new(url: "git://git.example.com/square/kochiku-name.git")
          repo.valid?
          expect(repo.name).to eq("kochiku-name")
        end
      end
    end

    context "name" do
      before do
        @repo1 = FactoryBot.create(:repository, url: "git@git.example.com:kansas/kansas-city.git")
      end

      it "should allow two repositories with the same name from different namespaces" do
        repo2 = Repository.new(url: "git://git.example.com/missouri/kansas-city.git")
        expect(repo2).to be_valid
      end

      it "should not allow two repositories with the same name and namespaces" do
        repo2 = Repository.new(url: "git://github.com/kansas/kansas-city.git")
        repo2.valid?
        expect(repo2).to have(1).error_on(:name)
        expect(repo2.errors.full_messages).to include("Namespace + Name combination already exists")
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
      expect(Repository.new(:on_green_update => "a,b,c").promotion_refs).to eq(%w( a b c ))
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

  context "#run_ci=" do
    it "converts the checkbox to bool" do
      repository = FactoryBot.create(:repository)
      repository.run_ci = "1"
      repository.save
      repository.reload
      expect(repository.run_ci).to eq(true)
      repository.run_ci = "0"
      repository.save
      repository.reload
      expect(repository.run_ci).to eq(false)
    end
  end

  context "#build_pull_requests=" do
    it "converts the checkbox to bool" do
      repository = FactoryBot.create(:repository)
      repository.build_pull_requests = "1"
      repository.save
      repository.reload
      expect(repository.build_pull_requests).to eq(true)
      repository.build_pull_requests = "0"
      repository.save
      repository.reload
      expect(repository.build_pull_requests).to eq(false)
    end
  end

  it "saves build tags" do
    repository = FactoryBot.create(:repository)
    repository.on_green_update = "1,2,3"
    repository.save
    repository.reload
    expect(repository.on_green_update).to eq("1,2,3")
  end

  describe '#build_for_commit' do
    let!(:repositoryA) { FactoryBot.create(:repository) }
    let!(:repositoryB) { FactoryBot.create(:repository) }
    let!(:branchA1) { FactoryBot.create(:branch, repository: repositoryA) }
    let!(:branchB1) { FactoryBot.create(:branch, repository: repositoryB) }
    let(:sha) { to_40('a') }

    it "should return the build associated with the repository" do
      buildA1 = FactoryBot.create(:build, branch_record: branchA1, ref: sha)
      expect(repositoryA.build_for_commit(sha)).to eq(buildA1)
      expect(repositoryB.build_for_commit(sha)).to be_nil

      buildB1 = FactoryBot.create(:build, branch_record: branchB1, ref: sha)
      expect(repositoryA.build_for_commit(sha)).to eq(buildA1)
      expect(repositoryB.build_for_commit(sha)).to eq(buildB1)
    end
  end

  describe '#ensure_build_exists' do
    let(:repository) { FactoryBot.create(:repository) }
    let(:branch) { FactoryBot.create(:branch, repository: repository) }

    it 'creates a new build only if one does not exist' do
      sha = to_40('abcdef')
      build1 = repository.ensure_build_exists(sha, branch)
      build2 = repository.ensure_build_exists(sha, branch)

      expect(build1).not_to eq(nil)
      expect(build1).to eq(build2)

      expect(build1.branch_record).to eq(branch)
      expect(build1.ref).to eq(sha)
      expect(build1.state).to eq('partitioning')
    end
  end
end
