require 'spec_helper'

describe PullRequestsController do
  let(:project) { Factory.create(:project) }

  describe "post /build/:id" do
    it "creates a build for a pull request" do
      expect {
        post :build, :id => project.id, 'payload' => payload
        response.should be_success
      }.to change(project.builds, :count).by(1)
      build = project.builds.last
      build.branch.should == "branch-name"
      build.ref.should == "Some-sha"
      build.queue.should == :developer
    end

    it "does not create a pull request if not requested" do
      expect {
        post :build, :id => project.id, 'payload' => payload({"pull_request" => {"body" => "don't build it"}})
        response.should be_success
      }.to_not change(project.builds, :count).by(1)
    end

    it "ignores !buildme casing" do
      expect {
        post :build, :id => project.id, 'payload' => payload({"pull_request" => {"body" => "!BuIlDMe"}})
        response.should be_success
      }.to change(project.builds, :count).by(1)
    end

    it "does not build a closed pull request" do
      expect {
        post :build, :id => project.id, 'payload' => payload({"action" => "closed"})
        response.should be_success
      }.to_not change(project.builds, :count).by(1)
    end

    it "does not blow up if action is missing" do
      post :build, :id => project.id, 'payload' => payload({"action" => nil})
      response.should be_success
    end

    it "does not blow up if pull_request is missing" do
      expect {
        post :build, :id => project.id, 'payload' => payload({"pull_request" => nil})
        response.should be_success
      }.to_not change(project.builds, :count).by(1)
    end
  end

  def payload(options = {})
    defaults = {
      "pull_request" => {
        "head" => {
          "sha" => "Some-sha",
          "ref" => "branch-name"
        },
        "body" => "best pull request ever !BUILDME",
        "title" => "this is a pull request",
      },
      "action" => "synchronize",
    }.deep_merge(options)
  end

end
