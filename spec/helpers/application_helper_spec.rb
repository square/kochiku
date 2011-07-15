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

    it "should return failed when state = :error" do
      @build.state = :error
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
end