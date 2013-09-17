require 'spec_helper'

describe Repository do
  before do
    settings = SettingsAccessor.new(<<-YAML)
    git_servers:
      stash.example.com:
        type: stash
      git.example.com:
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
        subject.should be_nil
      end
    end

    context 'with a matching main project name' do
      let!(:main_project) do
        repository.projects.create name: repository.repository_name
      end

      it 'returns the main project' do
        subject.should == main_project
      end
    end
  end

  context "#interested_github_events" do
    it 'includes push if run_ci is enabled' do
      Repository.new(:run_ci => true).interested_github_events.should == ['pull_request', 'push']
    end
    it 'does not include push if run_ci is enabled' do
      Repository.new(:run_ci => false).interested_github_events.should == ['pull_request']
    end
  end

  context "#promotion_refs" do
    it "is an empty array when promotion_refs is a empty string" do
      Repository.new(:on_green_update => "").promotion_refs.should == []
    end

    it "is an empty array when promotion_refs is a blank string" do
      Repository.new(:on_green_update => "   ").promotion_refs.should == []
    end

    it "is an empty array when promotion_refs is comma" do
      Repository.new(:on_green_update => "  , ").promotion_refs.should == []
    end

    it "splits on comma's" do
      Repository.new(:on_green_update => "a,b,c").promotion_refs.should == ["a", "b", "c"]
    end
  end

  context "#base_api_url" do
    it "handles ssh urls" do
      repo = Repository.new(url: "git@git.example.com:square/kochiku.git")
      repo.base_api_url.should == "https://git.example.com/api/v3/repos/square/kochiku"
    end
  end

  context "#base_html_url" do
    it "handles ssh urls" do
      repo = Repository.new(url: "git@git.example.com:square/kochiku.git")
      repo.base_html_url.should == "https://git.example.com/square/kochiku"
    end
    it "handles http urls" do
      repo = Repository.new(url: "http://git.example.com/square/kochiku.git")
      repo.base_html_url.should == "https://git.example.com/square/kochiku"
    end
    it "handles https urls" do
      repo = Repository.new(url: "https://git.example.com/square/kochiku.git")
      repo.base_html_url.should == "https://git.example.com/square/kochiku"
    end
    it "handles git read only urls" do
      repo = Repository.new(url: "git://git.example.com/square/kochiku.git")
      repo.base_html_url.should == "https://git.example.com/square/kochiku"
    end
  end

  context "#repository_name" do
    context "respository_name is set" do
      it "returns the value" do
        repo = Repository.new(url: "git://git.example.com/square/kochiku-name.git",
            repository_name: "another_project")
        repo.save
        repo.reload
        repo.repository_name.should == "another_project"
      end
    end

    context "repository_name is not set when saving" do
      it "sets the repository name based on the " do
        repo = Repository.new(url: "git://git.example.com/square/kochiku-name.git")
        repo.save
        repo.reload
        repo.repository_name.should == "kochiku-name"
      end

      context "when that name already exists" do
        let!(:existing_repo) { FactoryGirl.create(:repository, repository_name: 'my-repo') }

        it "does not validate" do
          repo = FactoryGirl.build(:repository, repository_name: 'my-repo')
          expect(repo).to_not be_valid
        end
      end
    end
  end

  context "with stash repository" do
    context "#repository_name" do
      it "returns the repositories name" do
        repo = Repository.new(url: "ssh://git@stash.example.com:7999/pe/host-tools.git")
        repo.valid?
        repo.repository_name.should == "host-tools"
      end
    end

    context '.project_params' do
      it 'parses out pertinent information' do
        repo = Repository.new(url: "ssh://git@stash.example.com:7999/pe/host-tools.git")
        repo.valid?
        expect(repo.project_params).to eq(
          host:       'stash.example.com',
          port:       7999,
          username:   'pe',
          repository: 'host-tools'
        )
      end
    end
  end

  context "#repo_cache_name" do
    it "returns the cache from the settings or the default from the repo name" do
      repository = Repository.new(:repo_cache_dir => "foobar")
      repository.repo_cache_name.should == "foobar"
    end

    it "returns the cache from the settings or the default from the repo name" do
      repository = Repository.new(url: "https://git.example.com/square/kochiku")
      repository.valid?
      repository.repo_cache_name.should == "kochiku-cache"
    end
  end

  context "#run_ci=" do
    it "converts the checkbox to bool" do
      repository = FactoryGirl.create(:repository)
      repository.run_ci="1"
      repository.save
      repository.reload
      repository.run_ci.should == true
      repository.run_ci="0"
      repository.save
      repository.reload
      repository.run_ci.should == false
    end
  end

  context "#build_pull_requests=" do
    it "converts the checkbox to bool" do
      repository = FactoryGirl.create(:repository)
      repository.build_pull_requests="1"
      repository.save
      repository.reload
      repository.build_pull_requests.should == true
      repository.build_pull_requests="0"
      repository.save
      repository.reload
      repository.build_pull_requests.should == false
    end
  end

  context "#use_branches_on_green=" do
    it "converts the checkbox to bool" do
      repository = FactoryGirl.create(:repository)
      repository.use_branches_on_green="1"
      repository.save
      repository.reload
      repository.use_branches_on_green.should == true
      repository.use_branches_on_green="0"
      repository.save
      repository.reload
      repository.use_branches_on_green.should == false
    end
  end

  it "saves build tags" do
    repository = FactoryGirl.create(:repository)
    repository.on_green_update="1,2,3"
    repository.save
    repository.reload
    repository.on_green_update.should == "1,2,3"
  end

  context "has_on_success_script?" do
    it "is false if the script is blank" do
      Repository.new(:on_success_script => "").has_on_success_script?.should be_false
      Repository.new(:on_success_script => nil).has_on_success_script?.should be_false
      Repository.new(:on_success_script => "  ").has_on_success_script?.should be_false
      Repository.new(:on_success_script => " \n ").has_on_success_script?.should be_false
    end

    it "is true if there is a script" do
      Repository.new(:on_success_script => "hi").has_on_success_script?.should be_true
    end
  end
end
