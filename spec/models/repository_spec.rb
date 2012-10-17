require 'spec_helper'

describe Repository do
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
      repository = Factory.create(:repository)
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
      repository = Factory.create(:repository)
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
      repository = Factory.create(:repository)
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
    repository = Factory.create(:repository)
    repository.on_green_update.should be_nil
    repository.on_green_update="1,2,3"
    repository.save
    repository.reload
    repository.on_green_update.should == "1,2,3"
  end
end
