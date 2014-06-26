require 'spec_helper'

describe BuildStateUpdateJob do
  let(:repository) { FactoryGirl.create(:repository, url: 'git@github.com:square/test-repo.git') }
  let(:project) { FactoryGirl.create(:big_rails_project, :repository => repository, :name => name) }
  let(:build) { FactoryGirl.create(:build, :state => :runnable, :project => project) }
  let(:name) { repository.name + "_pull_requests" }
  let(:current_repo_master) { build.ref }

  before do
    build.build_parts.create!(:kind => :spec, :paths => ["foo", "bar"], :queue => :ci)
    build.build_parts.create!(:kind => :cucumber, :paths => ["baz"], :queue => :ci)
    # TODO: This is terrible, need to fold this feedback back into the design.
    # We are stubbing methods that are not called from the class under test.
    allow(GitRepo).to receive(:load_kochiku_yml).and_return(nil)
    allow(GitRepo).to receive(:harmonize_remote_url)
    allow(GitRepo).to receive(:synchronize_with_remote).and_return(true)
    mocked_remote_server = RemoteServer.for_url(repository.url)
    allow(mocked_remote_server).to receive(:sha_for_branch).and_return(current_repo_master)
    allow(RemoteServer).to receive(:for_url).with(repository.url).and_return(mocked_remote_server)
    allow(GitBlame).to receive(:last_email_in_branch).and_return("example@email.com")
    allow(BuildStrategy).to receive(:promote_build)
    allow(BuildStrategy).to receive(:run_success_script)
    stub_request(:post, %r{#{repository.base_api_url}/statuses})
  end

  shared_examples "a non promotable state" do
    it "should not promote the build" do
      expect(BuildStrategy).not_to receive(:promote_build)
      BuildStateUpdateJob.perform(build.id)
    end
  end

  describe "#perform" do
    it "updates github when a build passes" do
      states = []
      stub_request(:post, "#{repository.base_api_url}/statuses/#{build.ref}").with do |request|
        expect(request.headers["Authorization"]).to eq("token #{GithubRequest::OAUTH_TOKEN}")
        body = JSON.parse(request.body)
        states << body["state"]
        true
      end

      BuildStateUpdateJob.perform(build.id)

      build.build_parts.each do |part|
        build_attempt = part.build_attempts.create!(:state => :running)
        build_attempt.finish!(:passed)
      end

      BuildStateUpdateJob.perform(build.id)
      expect(states).to eq(["pending", "success"])
    end


    context "when all parts have passed" do
      before do
        build.build_parts.each do |part|
          attempt = part.build_attempts.create!(:state => :running)
          attempt.finish!(:passed)
        end
      end

      describe "checking for newer sha's after finish" do
        subject { BuildStateUpdateJob.perform(build.id) }
        it "doesn't kick off a new build for normal porjects" do
          expect { subject }.to_not change(project.builds, :count)
        end

        context "with ci project" do
          let(:name) { repository.name }

          context "new sha is available" do
            let(:current_repo_master) { "new-sha-11111111111111111111111111111111" }

            it "builds when there is a new sha to build" do
              expect { subject }.to change(project.builds, :count).by(1)
              build = project.builds.last
              expect(build.ref).to eq(current_repo_master)
            end

            # TODO: this shouldn't be under the "when all parts have passed" context
            it "does not kick off a new build unless finished" do
              build.build_parts.first.build_attempts.last.finish!(:running)
              expect { subject }.to_not change(project.builds, :count)
            end

            it "kicks off a new build if attempts are running on a part that passed" do
              build.build_parts.first.create_and_enqueue_new_build_attempt!
              expect { subject }.to change(project.builds, :count).by(1)
              build = project.builds.last
              expect(build.ref).to eq(current_repo_master)
            end

            it "does not kick off a new build if one is already running" do
              project.builds.create!(:ref => 'some-other-sha-1111111111111111111111111', :state => :partitioning, :branch => 'master')
              expect { subject }.to_not change(project.builds, :count)
            end

            it "does not roll back a builds state" do
              new_build = project.builds.create!(:ref => current_repo_master, :state => :failed, :branch => 'master')
              expect { subject }.to_not change(project.builds, :count)
              expect(new_build.reload.state).to eq(:failed)
            end

          end

          context "no new sha" do
            it "does not build" do
              expect { subject }.to_not change(project.builds, :count)
            end
          end
        end
      end

      context "on main project" do
        let(:project) { FactoryGirl.create(:project, :repository => repository, :name => repository.name) }

        it "should promote the build" do
          expect(BuildStrategy).to receive(:promote_build).with(build.ref, build.repository)
          expect(BuildStrategy).not_to receive(:run_success_script)
          BuildStateUpdateJob.perform(build.id)
        end

        context "with a success script" do
          before do
            repository.update_attribute(:on_success_script, "./this_is_a_triumph")
          end

          it "promote the build only once" do
            expect(BuildStrategy).to receive(:run_success_script).once.with(build.repository, build.ref, build.branch).and_return("this is a log file\n\n")
            2.times {
              BuildStateUpdateJob.perform(build.id)
            }
            expect(build.reload.on_success_script_log_file.read).to eq("this is a log file\n\n")
          end
        end
      end

      it "kochiku should merge the branch if eligible" do
        build.update_attributes(:merge_on_success => true)
        expect(BuildStrategy).to receive(:merge_ref).with(build)
        BuildStateUpdateJob.perform(build.id)
      end
    end

    context "when a part has failed but some are still running" do
      before do
        build.build_parts.first.build_attempts.create!(:state => :failed)
      end

      it_behaves_like "a non promotable state"
    end

    context "when all parts have run and some have failed" do
      before do
        (build.build_parts - [build.build_parts.first]).each do |part|
          part.build_attempts.create!(:state => :passed)
        end
        build.build_parts.first.build_attempts.create!(:state => :failed)
      end

      it_behaves_like "a non promotable state"
    end

    context "when no parts" do
      before do
        build.build_parts.destroy_all
      end

      it "should not update the state" do
        expect {
          BuildStateUpdateJob.perform(build.id)
        }.to_not change { build.reload.state }
      end

      it_behaves_like "a non promotable state"
    end
  end
end
