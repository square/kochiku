require 'spec_helper'

describe Repository do
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
      repo = Repository.new(:url => "git@git.squareup.com:square/kochiku.git")
      repo.base_api_url.should == "https://git.squareup.com/api/v3/repos/square/kochiku"
    end
  end

  context "#base_html_url" do
    it "handles ssh urls" do
      repo = Repository.new(:url => "git@git.squareup.com:square/kochiku.git")
      repo.base_html_url.should == "https://git.squareup.com/square/kochiku"
    end
    it "handles http urls" do
      repo = Repository.new(:url => "http://git.squareup.com/square/kochiku.git")
      repo.base_html_url.should == "https://git.squareup.com/square/kochiku"
    end
    it "handles https urls" do
      repo = Repository.new(:url => "https://git.squareup.com/square/kochiku.git")
      repo.base_html_url.should == "https://git.squareup.com/square/kochiku"
    end
    it "handles git read only urls" do
      repo = Repository.new(:url => "git://git.squareup.com/square/kochiku.git")
      repo.base_html_url.should == "https://git.squareup.com/square/kochiku"
    end
  end

  context "#repository_name" do
    it "returns the repositories name" do
      repo = Repository.new(:url => "git://git.squareup.com/square/kochiku-name.git")
      repo.repository_name.should == "kochiku-name"
    end
  end

  context "with stash repository" do
    context "#repository_name" do
      it "returns the repositories name" do
        repo = Repository.new(:url => "ssh://git@stash.squareup.com:7999/pe/host-tools.git")
        repo.repository_name.should == "host-tools"
      end
    end
  end

  context "#repo_cache_name" do
    it "returns the cache from the settings or the default from the repo name" do
      repository = Repository.new(:repo_cache_dir => "foobar")
      repository.repo_cache_name.should == "foobar"
    end

    it "returns the cache from the settings or the default from the repo name" do
      repository = Repository.new(:url => "https://git.squareup.com/square/kochiku")
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

  describe "#ci_queue_name" do
    it "returns queue override if present" do
      Repository.new(:queue_override => 'special').ci_queue_name.should == 'special'
    end

    it "returns ci if queue override is blank" do
      Repository.new(:queue_override => nil).ci_queue_name.should == 'ci'
      Repository.new(:queue_override => '').ci_queue_name.should == 'ci'
      Repository.new(:queue_override => '  ').ci_queue_name.should == 'ci'
    end
  end
end
