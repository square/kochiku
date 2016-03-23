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

  describe "#build" do
    describe "post /pull-request-builder" do
      context "from github" do
        let(:repository_fields) { Hash.new }  # expected to be overwritten by a sub-context
        let!(:repository) do
          FactoryGirl.create(:repository, { url: "git@github.com:sq_test_user/kochiku.git" }.merge(repository_fields))
        end

        context "for push events" do
          let(:repository_fields) { { run_ci: true } }
          let!(:master_branch) { FactoryGirl.create(:master_branch, repository: repository) }
          let!(:convergence_branch) { FactoryGirl.create(:branch, repository: repository, convergence: true, name: "convergence-branch") }
          let!(:nonconvergence_branch) { FactoryGirl.create(:branch, repository: repository, convergence: false, name: "nonconvergence-branch") }

          it "creates a build" do
            expect(Build.where(branch_id: master_branch.id, ref: global_sha)).to_not exist
            expect {
              post :build, push_params
              expect(response).to be_success
            }.to change(Build, :count).by(1)
            expect(Build.where(branch_id: master_branch.id, ref: global_sha)).to exist
          end

          it "does not create a build for pushes if branch not exist" do
            expect {
              post :build, push_params("ref" => "refs/heads/test-branch")
              expect(response).to be_success
            }.to_not change(Build, :count)
          end

          it "does not create a build for pushes if branch is not convergence" do
            expect {
              post :build, push_params("ref" => "refs/heads/nonconvergence-branch")
              expect(response).to be_success
            }.to_not change(Build, :count)
          end

          it "does not a build if repository disabled ci" do
            repository.update_attributes!(run_ci: false)
            expect {
              post :build, push_params
              expect(response).to be_success
            }.to_not change(Build, :count)
          end

          it "does not build if there is an active ci build" do
            master_branch.builds.create!(ref: to_40('w'), state: :succeeded)
            frozen_time = 3.seconds.from_now
            allow(Time).to receive(:now).and_return(frozen_time)
            master_branch.builds.create!(ref: to_40('y'), state: :partitioning)
            expect {
              post :build, push_params
              expect(response).to be_success
            }.to_not change(Build, :count)
          end

          it "builds for convergence branches" do
            expect {
              post :build, push_params("ref" => "refs/heads/convergence-branch")
              expect(response).to be_success
            }.to change(Build, :count).by(1)
          end

          it "builds if there is completed ci build" do
            master_branch.builds.create!(ref: to_40('w'), state: :succeeded)
            expect {
              post :build, push_params
              expect(response).to be_success
            }.to change(Build, :count).by(1)
          end

          it "builds if there is a completed ci build after a build that is still building" do
            master_branch.builds.create!(ref: to_40('w'), state: :partitioning)
            frozen_time = 3.seconds.from_now
            allow(Time).to receive(:now).and_return(frozen_time)
            master_branch.builds.create!(ref: to_40('y'), state: :succeeded)
            expect {
              post :build, push_params
              expect(response).to be_success
            }.to change(Build, :count).by(1)
          end

          it "it should not error if the repository url in the request is not found" do
            expect {
              post :build, push_params(
                "repository" =>
                  {
                    "ssh_url" => "git@git.github.com:doesnot/exist.git",
                    "html_url" => "https://github.com/doesnot/exist",
                    "name" => "exist",
                    "fullname" => "doesnot/exist"
                  }
              )
              expect(response).to be_success
            }.to_not change(Build, :count)
          end
        end

        context "for pull requests" do
          let(:repository_fields) { { run_ci: true, build_pull_requests: true } }

          context "when there is no existing Branch record" do
            it "should create a Branch record on demand" do
              expect(Branch.where(repository: repository, name: "test-branch")).to_not exist
              post :build, pull_request_params
              expect(response).to be_success
              expect(Branch.where(repository: repository, name: "test-branch")).to exist
            end
          end

          context "when the pull request sha has already been built" do
            let(:branch) { FactoryGirl.create(:branch, repository: repository, name: "test-branch") }

            it "has no effect" do
              FactoryGirl.create(:build, branch_id: branch.id, ref: global_sha)

              expect {
                post :build, pull_request_params
                expect(response).to be_success
              }.to_not change(Build, :count)
            end

            it "still creates a build if the sha is used by a different repo" do
              # create build with the same ref on a different repository
              FactoryGirl.create(:build, ref: global_sha)

              expect(Build.where(branch_id: branch.id, ref: global_sha)).to_not exist
              post :build, pull_request_params
              expect(Build.where(branch_id: branch.id, ref: global_sha)).to exist
            end
          end

          context do
            let(:branch) { FactoryGirl.create(:branch, repository: repository, name: "test-branch") }

            it "creates a build for a pull request" do
              expect(Build.where(branch_id: branch.id, ref: global_sha)).to_not exist
              expect {
                post :build, pull_request_params
                expect(response).to be_success
              }.to change(Build, :count).by(1)
              expect(Build.where(branch_id: branch.id, ref: global_sha)).to exist
            end

            it "does not create a build if build_pull_requests is disabled" do
              repository.update_attribute(:build_pull_requests, false)
              expect {
                post :build, pull_request_params
                expect(response).to be_success
              }.to_not change(branch.builds, :count)
            end

            it "does not build a closed pull request" do
              expect {
                post :build, pull_request_params({ "pull_request" => { "state" => "closed" } })
                expect(response).to be_success
              }.to_not change(branch.builds, :count)
            end

            it "does not blow up if state is missing" do
              post :build, pull_request_params({ "pull_request" => { "state" => nil } })
              expect(response).to be_success
            end

            context "when there are other builds for the same branch" do
              let!(:build_one) { FactoryGirl.create(:build, branch_record: branch, ref: to_40('w')) }
              let!(:build_two) { FactoryGirl.create(:build, branch_record: branch, ref: to_40('y')) }

              it "aborts previous builds of the same branch" do
                expect {
                  post :build, pull_request_params
                  expect(response).to be_success
                }.to change(Build, :count)
                expect(build_one.reload).to be_aborted
                expect(build_two.reload).to be_aborted
              end
            end
          end
        end

        it "does not blow up if pull_request data is missing" do
          expect {
            post :build, pull_request_params({ "pull_request" => nil })
            expect(response).to be_success
          }.to_not change(Build, :count)
        end

        it "should not error if the repository url in the request is not found" do
          expect {
            post :build, pull_request_params("repository" => { "ssh_url" => "git@git.example.com:doesnot/exist.git" })
            expect(response).to be_success
          }.to_not change(Build, :count)
        end
      end
    end
  end

  def global_sha
    "abc87b93ad4445b595a7c4b231862e7d99ab8c51"
  end

  def pull_request_params(options = {})
    {
      "action" => "opened",
      "pull_request" => {
        "state" => "open",
        "head" => {
          "ref" => "test-branch",
          "sha" => global_sha
        }
      },
      "repository" => {
        "name" => "kochiku",
        "full_name" => "sq_test_user/kochiku",
        "owner" => {
          "login" => "sq_test_user"
        },
        "ssh_url" => "git@github.com:sq_test_user/kochiku.git"
      }
    }.deep_merge(options)
  end

  def push_params(options = {})
    {
      "ref" => "refs/heads/master",
      "after" => global_sha,
      "repository" => {
        "name" => "kochiku",
        "full_name" => "sq_test_user/kochiku",
        "html_url" => "https://github.com/sq_test_user/kochiku",
        "ssh_url" => "git@github.com:sq_test_user/kochiku.git",
      }
    }.deep_merge(options)
  end
end
