require 'spec_helper'

describe PullRequestsController do
  before do
    settings = SettingsAccessor.new(<<-YAML)
    git_servers:
      github.com:
        type: github
      git.example.com:
        type: github
    YAML
    stub_const "Settings", settings
  end

  let!(:repository) { FactoryGirl.create(:repository, :url => "git@git.example.com:square/web.git", :run_ci => true) }

  describe "#build" do
    describe "post /pull-request-builder" do
      context "for push events" do
        let!(:project) { FactoryGirl.create(:project, :name => "web", :repository => repository) }

        it "creates the default project if required" do
          project.update_attributes!(:name => "web-something")
          expect {
            post :build, 'payload' => push_payload
            expect(response).to be_success
          }.to change(Project, :count).by(1)
          expect(Project.last.repository).to eq(repository)
          expect(Project.last.name).to eq("web")
        end

        it "does not duplicate the default project" do
          expect {
            post :build, 'payload' => push_payload
            expect(response).to be_success
          }.to_not change(Project, :count)
        end

        it "creates a build" do
          expect {
            post :build, 'payload' => push_payload
            expect(response).to be_success
          }.to change(Build, :count).by(1)
          build = Build.last
          expect(build.branch).to eq("master")
          expect(build.ref).to eq(to_40('2'))
        end

        it "does not a build for not master" do
          expect {
            post :build, 'payload' => push_payload("ref" => "refs/heads/some-branch")
            expect(response).to be_success
          }.to_not change(Build, :count)
        end

        it "does not a build if repository disabled ci" do
          repository.update_attributes!(:run_ci => false)
          expect {
            post :build, 'payload' => push_payload
            expect(response).to be_success
          }.to_not change(Build, :count)
        end

        it "does not build if there is an active ci build" do
          project.builds.create!(:ref => to_40('w'), :state => :succeeded, :branch => 'master')
          frozen_time = 3.seconds.from_now
          allow(Time).to receive(:now).and_return(frozen_time)
          project.builds.create!(:ref => to_40('y'), :state => :partitioning, :branch => 'master')
          expect {
            post :build, 'payload' => push_payload
            expect(response).to be_success
          }.to_not change(Build, :count)
        end

        it "builds if there is completed ci build" do
          project.builds.create!(:ref => to_40('w'), :state => :succeeded, :branch => 'master')
          expect {
            post :build, 'payload' => push_payload
            expect(response).to be_success
          }.to change(Build, :count).by(1)
        end

        it "builds if there is a completed ci build after a build that is still building" do
          project.builds.create!(:ref => to_40('w'), :state => :partitioning, :branch => 'master')
          frozen_time = 3.seconds.from_now
          allow(Time).to receive(:now).and_return(frozen_time)
          project.builds.create!(:ref => to_40('y'), :state => :succeeded, :branch => 'master')
          expect {
            post :build, 'payload' => push_payload
            expect(response).to be_success
          }.to change(Build, :count).by(1)
        end

        it "it should not error if the repository url in the request is not found" do
          expect {
            post :build, 'payload' => push_payload("repository" => {"url" => "git@git.example.com:doesnot/exist.git"})
            expect(response).to be_success
          }.to_not change(Build, :count)
        end
      end

      context "for pull requests" do
        before do
          repository.update_attribute(:build_pull_requests, true)
        end

        it "creates the pull request project" do
          expect {
            post :build, 'payload' => pull_request_payload
            expect(response).to be_success
          }.to change(Project, :count).by(1)
          expect(Project.last.repository).to eq(repository)
          expect(Project.last.name).to eq("web-pull_requests")
        end

        it "creates a build for a pull request" do
          expect {
            post :build, 'payload' => pull_request_payload
            expect(response).to be_success
          }.to change(Build, :count).by(1)
          build = Build.last
          expect(build.branch).to eq("branch-name")
          expect(build.ref).to eq(to_40('1'))
        end

        it "will enqueue a build if autobuild pull requests is enabled" do
          github_payload = pull_request_payload("pull_request" => {
            "head" => {"sha" => to_40('1'), "ref" => "branch-name"},
            "body" => "best pull request ever",
          })
          expect {
            post :build, 'payload' => github_payload
            expect(response).to be_success
          }.to change(Build, :count).by(1)
        end

        context "when the pull request sha has already been built" do
          before do
            @github_payload = pull_request_payload("pull_request" => {
              "head" => {"sha" => "de8251ff97ee194a289832576287d6f8ad74e3d0", "ref" => "branch-name"},
              "body" => "best pull request ever",
            })
          end

          it "has no effect" do
            project = FactoryGirl.create(:project, :repository => repository)
            build = FactoryGirl.create(:build, :project => project, :ref => "de8251ff97ee194a289832576287d6f8ad74e3d0")
            expect {
              post :build, 'payload' => @github_payload
              expect(response).to be_success
            }.to_not change(Build, :count)
          end

          it "still creates a build if the sha is used by a different repo" do
            project = FactoryGirl.create(:project)
            FactoryGirl.create(:build, project: project, ref: "de8251ff97ee194a289832576287d6f8ad74e3d0")

            expect {
              post :build, 'payload' => @github_payload
            }.to change(Build, :count).by(1)
          end
        end

        context "with a project" do
          let(:project) { FactoryGirl.create(:project, :name => "web-pull_requests", :repository => repository) }

          it "does not create a pull request if not requested" do
            repository.update_attribute(:build_pull_requests, false)
            expect {
              post :build, 'payload' => pull_request_payload({"pull_request" => {"body" => "don't build it"}})
              expect(response).to be_success
            }.to_not change(project.builds, :count)
          end

          it "does not build a closed pull request" do
            expect {
              post :build, 'payload' => pull_request_payload({"action" => "closed"})
              expect(response).to be_success
            }.to_not change(project.builds, :count)
          end

          it "does not blow up if action is missing" do
            post :build, 'payload' => pull_request_payload({"action" => nil})
            expect(response).to be_success
          end

          context "when there are other builds for the same branch" do
            let(:branch_name) { "test-branch" }
            let!(:build_one) { FactoryGirl.create(:build, :project => project, :branch => branch_name, :ref => to_40('w')) }
            let!(:build_two) { FactoryGirl.create(:build, :project => project, :branch => branch_name, :ref => to_40('y')) }

            before do
              repository.update_attribute(:build_pull_requests, true)
            end

            it "aborts previous builds of the same branch" do
              github_payload = pull_request_payload("pull_request" => {
                  "head" => {"sha" => to_40('z'), "ref" => branch_name},
                  "body" => "best pull request ever",
              })

              expect {
                post :build, 'payload' => github_payload
                expect(response).to be_success
              }.to change(Build, :count)
              expect(build_one.reload).to be_aborted
              expect(build_two.reload).to be_aborted
            end
          end
        end

        it "does not blow up if pull_request is missing" do
          expect {
            post :build, 'payload' => pull_request_payload({"pull_request" => nil})
            expect(response).to be_success
          }.to_not change(Build, :count)
        end

        it "it should not error if the repository url in the request is not found" do
          expect {
            pr_payload = pull_request_payload("repository" => { "ssh_url" => "git@git.example.com:doesnot/exist.git" })
            post :build, 'payload' => pr_payload
            expect(response).to be_success
          }.to_not change(Build, :count)
        end
      end
    end
  end

  def pull_request_payload(options = {})
    {
      "pull_request" => {
        "head" => {
          "sha" => to_40('1'),
          "ref" => "branch-name"
        },
        "body" => "best pull request ever",
        "title" => "this is a pull request",
      },
      "repository" => {
        "ssh_url" => "git@git.example.com:square/web.git",
      },
      "action" => "synchronize",
    }.deep_merge(options).to_json
  end

  def push_payload(options = {})
    {
      "after" => to_40('2'),
      "repository" => {
        "url" => "https://git.example.com/square/web",
      },
      "ref" => "refs/heads/master",
    }.deep_merge(options).to_json
  end
end
