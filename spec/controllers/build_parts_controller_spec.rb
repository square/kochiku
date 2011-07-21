require 'spec_helper'

describe BuildPartsController do
  render_views

  describe "#show" do
    it "renders the show template successfully even if elapsed time is nil" do
      project = projects(:big_rails_app)
      build = project.builds.create!(:ref => "abcdef", :queue => :ci, :state => :partitioning)
      build_part = build.build_parts.create!(:paths => ["a"], :kind => "test")
      build_part.elapsed_time.should == nil
      get :show, :project_id => project.to_param, :build_id => build.to_param, :id => build_part.to_param
      response.should be_success
      response.should render_template("build_parts/show")
    end
  end
end
