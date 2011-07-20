require 'spec_helper'

describe BuildPartsController do
  render_views

  describe "#show" do
    it "renders the show template successfully even if elapsed time is nil" do
      build = Build.build_sha!(:project => projects(:big_rails_app), :sha => "abcdef", :queue => :master)
      build_part = BuildPart.create!(:build => build, :paths => ["a"], :kind => "test")
      build_part.elapsed_time.should == nil
      get :show, :build_id => build.to_param, :id => build_part.to_param
      response.should be_success
      response.should render_template("build_parts/show")
    end
  end
end
