require 'spec_helper'

describe RepositoriesController do
  render_views
  describe "post /repositories" do
    it "creates a repository" do
      expect{
        post :create, :repository => {:url => "git@git.squareup.com:square/kochiku.git", :test_command => "script/something"}
        response.should be_redirect
      }.to change(Repository, :count).by(1)
      Repository.last.url.should == "git@git.squareup.com:square/kochiku.git"
      Repository.last.test_command.should == "script/something"
    end

    it "creates a ci project" do
      expect{
        post :create, :repository => {:url => "git@git.squareup.com:square/kochiku.git", :test_command => "script/something"}
        response.should be_redirect
      }.to change(Project, :count).by(2)
      Repository.last.projects.size.should == 2
      Repository.last.projects.map(&:name).sort.should == ["kochiku", "kochiku-pull_requests"]
    end
  end

  describe "put /repositories/:id" do
    let!(:repository) { FactoryGirl.create(:repository, :url => "git@git.squareup.com:square/kochiku.git", :test_command => "script/something")}
    it "creates a repository" do
      expect{
        put :update, :id => repository.id, :repository => {:url => "git@git.squareup.com:square/kochiku-worker.git", :test_command => "script/something-else"}
        response.should be_redirect
      }.to_not change(Repository, :count).by(1)
      Repository.last.url.should == "git@git.squareup.com:square/kochiku-worker.git"
      Repository.last.test_command.should == "script/something-else"
    end
  end

  describe "get /repositories" do
    it "responds with success" do
      get :index
      response.should be_success
    end
  end

  describe "get /repositories/:id/edit" do
    it "responds with success" do
      get :edit, :id => FactoryGirl.create(:repository).id
      response.should be_success
    end
  end

  describe "get /repositories/new" do
    it "responds with success" do
      get :new
      response.should be_success
    end
  end
end
