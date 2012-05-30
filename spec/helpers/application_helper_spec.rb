require 'spec_helper'

describe ApplicationHelper do
  include ActionView::Helpers
  include Haml::Helpers

  describe "#build_success_in_words" do
    before do
      @build = Build.new
    end

    it "should return success when state = :succeeded" do
      @build.state = :succeeded
      build_success_in_words(@build).should == 'success'
    end

    it "should return failed when state = :errored" do
      @build.state = :errored
      build_success_in_words(@build).should == 'failed'
    end

    it "should return failed when state = :doomed" do
      @build.state = :doomed
      build_success_in_words(@build).should == 'failed'
    end

    it "should return state otherwise" do
      @build.state = :partitioning
      build_success_in_words(@build).should == 'partitioning'
    end
  end

  describe "#show_link_to_commit" do
    it "should create a url to github based on config" do
      show_link_to_commit('SHA1').should == 'https://git.squareup.com/square/web/commit/SHA1'
    end
  end

  describe "#show_link_to_compare" do
    it "creates a url to github showing the diff between 2 SHAs" do
      show_link_to_compare('SHA1', 'SHA2').should == 'https://git.squareup.com/square/web/pull/new/square:SHA1...SHA2#files_bucket'
    end
  end

  describe "#show_link_to_create_pull_request" do
    it "creates a url to github for a pull request" do
      show_link_to_create_pull_request('SHA1').should == 'https://git.squareup.com/square/web/pull/new/square:master...SHA1'
    end
  end
end
