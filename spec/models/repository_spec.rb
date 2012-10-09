require 'spec_helper'

describe Repository do
  it "serializes options" do
    repository = Factory.create(:repository, :options => {'tmp_dir' => 'web-cache'})
    repository.reload
    repository.options.should == {'tmp_dir' => 'web-cache'}
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

  context "#repo_cache_name" do
    it "returns the cache from the settings or the default from the repo name" do
      repository = Repository.new(:options => {:tmp_dir => "foobar"})
      repository.repo_cache_name.should == "foobar"
    end

    it "returns the cache from the settings or the default from the repo name" do
      repository = Repository.new(:url => "https://git.squareup.com/square/kochiku")
      repository.repo_cache_name.should == "kochiku-cache"
    end
  end
end
