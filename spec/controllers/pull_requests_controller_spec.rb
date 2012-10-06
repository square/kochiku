require 'spec_helper'

describe PullRequestsController do
  let(:project) { Factory.create(:project) }

  describe "post /build/:id" do
    it "creates a build for a pull request" do
      post :build, :id => project.id
      response.should be_success
    end
  end
end
