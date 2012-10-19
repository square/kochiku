require 'spec_helper'

describe PullRequestsController do
  let!(:repository) { Factory.create(:repository, :url => "git@git.squareup.com:square/web.git", :run_ci => true) }

  describe "post /pull-request-builder" do
    context "for push events" do
      let!(:project) { Factory.create(:project, :name => "web", :repository => repository) }

      it "creates the default project if required" do
        project.update_attributes!(:name => "web-something")
        expect {
          post :build, 'payload' => push_payload
          response.should be_success
        }.to change(Project, :count).by(1)
        Project.last.repository.should == repository
        Project.last.name.should == "web"
      end

      it "does not duplicate the default project" do
        expect {
          post :build, 'payload' => push_payload
          response.should be_success
        }.to_not change(Project, :count)
      end

      it "creates a build" do
        expect {
          post :build, 'payload' => push_payload
          response.should be_success
        }.to change(Build, :count).by(1)
        build = Build.last
        build.branch.should == "master"
        build.ref.should == "SOME-SHA1"
        build.queue.should == :ci
      end

      it "does not a build for not master" do
        expect {
          post :build, 'payload' => push_payload("ref" => "refs/heads/some-branch")
          response.should be_success
        }.to_not change(Build, :count)
      end

      it "does not a build if repository disabled ci" do
        repository.update_attributes!(:run_ci => false)
        expect {
          post :build, 'payload' => push_payload
          response.should be_success
        }.to_not change(Build, :count)
      end

      it "does not build if there is an active ci build" do
        project.builds.create!(:ref => "sha", :state => :succeeded, :queue => :ci, :branch => 'master')
        frozen_time = 3.seconds.from_now
        Time.stub(:now).and_return(frozen_time)
        project.builds.create!(:ref => "sha2", :state => :partitioning, :queue => :ci, :branch => 'master')
        expect {
          post :build, 'payload' => push_payload
          response.should be_success
        }.to_not change(Build, :count)
      end

      it "builds if there is completed ci build" do
        project.builds.create!(:ref => "sha", :state => :succeeded, :queue => :ci, :branch => 'master')
        expect {
          post :build, 'payload' => push_payload
          response.should be_success
        }.to change(Build, :count).by(1)
      end

      it "builds if there is completed ci build after a build that is still building" do
        project.builds.create!(:ref => "sha", :state => :partitioning, :queue => :ci, :branch => 'master')
        frozen_time = 3.seconds.from_now
        Time.stub(:now).and_return(frozen_time)
        project.builds.create!(:ref => "sha2", :state => :succeeded, :queue => :ci, :branch => 'master')
        expect {
          post :build, 'payload' => push_payload
          response.should be_success
        }.to change(Build, :count).by(1)
      end
    end

    context "for pull requests" do
      it "creates the pull request project" do
        expect {
          post :build, 'payload' => pull_request_payload
          response.should be_success
        }.to change(Project, :count).by(1)
        Project.last.repository.should == repository
        Project.last.name.should == "web-pull_requests"
      end
      it "creates a build for a pull request" do
        expect {
          post :build, 'payload' => pull_request_payload
          response.should be_success
        }.to change(Build, :count).by(1)
        build = Build.last
        build.branch.should == "branch-name"
        build.ref.should == "Some-sha"
        build.queue.should == :developer
      end
      it "will enqueue a build if autobuild pull requests is enabled" do
        repository.build_pull_requests = "1"
        repository.save!
        github_payload = pull_request_payload("pull_request" => {
          "head" => { "sha" => "Some-sha", "ref" => "branch-name" },
          "body" => "best pull request ever",
        })
        expect {
          post :build, 'payload' => github_payload
          response.should be_success
        }.to change(Build, :count).by(1)
      end

      context "with a project" do
        let(:project) { Factory.create(:project, :name => "web-pull_requests", :repository => repository) }

        it "does not create a pull request if not requested" do
          expect {
            post :build, 'payload' => pull_request_payload({"pull_request" => {"body" => "don't build it"}})
            response.should be_success
          }.to_not change(project.builds, :count).by(1)
        end
        it "ignores !buildme casing" do
          expect {
            post :build, 'payload' => pull_request_payload({"pull_request" => {"body" => "!BuIlDMe"}})
            response.should be_success
          }.to change(project.builds, :count).by(1)
        end

        it "does not build a closed pull request" do
          expect {
            post :build, 'payload' => pull_request_payload({"action" => "closed"})
            response.should be_success
          }.to_not change(project.builds, :count).by(1)
        end

        it "does not blow up if action is missing" do
          post :build, 'payload' => pull_request_payload({"action" => nil})
          response.should be_success
        end
      end

      it "does not blow up if pull_request is missing" do
        expect {
          post :build, 'payload' => pull_request_payload({"pull_request" => nil})
          response.should be_success
        }.to_not change(Build, :count)
      end
    end
  end

  def pull_request_payload(options = {})
    {
      "pull_request" => {
        "head" => {
          "sha" => "Some-sha",
          "ref" => "branch-name"
        },
        "body" => "best pull request ever !BUILDME",
        "title" => "this is a pull request",
      },
      "repository" => {
        "ssh_url" => "git@git.squareup.com:square/web.git",
      },
      "action" => "synchronize",
    }.deep_merge(options).to_json
  end

  def push_payload(options = {})
    {
      "after" => "SOME-SHA1",
      "repository" => {
        "url" => "https://git.squareup.com/square/web",
      },
      "ref" => "refs/heads/master",
    }.deep_merge(options).to_json
  end

end
