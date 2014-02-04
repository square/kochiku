require 'spec_helper'

describe ApplicationHelper do
  include ActionView::Helpers
  include Haml::Helpers
  let(:project) { FactoryGirl.create(:project, :repository => repository)}
  let(:repository) { FactoryGirl.create(:repository, :url => "git@git.example.com:square/web.git")}

  before do
    settings = SettingsAccessor.new(<<-YAML)
    git_servers:
      git.example.com:
        type: github
    YAML
    stub_const "Settings", settings
  end

  before do
    @build = Build.new(:ref => "SHA1FORCOMMIT", :project => project, :branch => "nomnomnom")
  end

  describe "#build_success_in_words" do

    it "should return success when state = :succeeded" do
      @build.state = :succeeded
      expect(build_success_in_words(@build)).to eq('success')
    end

    it "should return failed when state = :errored" do
      @build.state = :errored
      expect(build_success_in_words(@build)).to eq('failed')
    end

    it "should return failed when state = :doomed" do
      @build.state = :doomed
      expect(build_success_in_words(@build)).to eq('failed')
    end

    it "should return state otherwise" do
      @build.state = :partitioning
      expect(build_success_in_words(@build)).to eq('partitioning')
    end
  end

  describe "#link_to_commit" do
    it "should create a link to the github url" do
      expect(link_to_commit(@build)).to eq(%{<a href="#{show_link_to_commit(@build)}">SHA1FOR</a>})
    end
  end

  describe "#show_link_to_commit" do
    it "should create a url to github based on config" do
      expect(show_link_to_commit(@build)).to eq('https://git.example.com/square/web/commit/SHA1FORCOMMIT')
    end
  end

  describe "#show_link_to_branch" do
    it "should create a url to github based on config" do
      expect(show_link_to_branch(@build)).to eq('https://git.example.com/square/web/tree/nomnomnom')
    end
  end

  describe "#show_link_to_compare" do
    it "creates a url to github showing the diff between 2 SHAs" do
      expect(show_link_to_compare(@build, 'SHA1FORCOMMIT', 'SHA2FORCOMMIT')).to eq('https://git.example.com/square/web/compare/SHA1FORCOMMIT...SHA2FORCOMMIT#files_bucket')
    end
  end

  describe "#show_link_to_create_pull_request" do
    it "creates a url to github for a pull request" do
      expect(show_link_to_create_pull_request(@build)).to eq('https://git.example.com/square/web/pull/new/master...SHA1FORCOMMIT')
    end
  end
end
