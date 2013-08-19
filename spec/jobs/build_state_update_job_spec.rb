require 'spec_helper'

describe BuildStateUpdateJob do
  let(:project) { FactoryGirl.create(:big_rails_project, :repository => repository, :name => name) }
  let(:repository) { FactoryGirl.create(:repository)}
  let(:build) { FactoryGirl.create(:build, :state => :runnable, :project => project) }
  let(:name) { repository.repository_name + "_pull_requests" }
  let(:current_repo_master) { build.ref }

  before do
    build.build_parts.create!(:kind => :spec, :paths => ["foo", "bar"])
    build.build_parts.create!(:kind => :cucumber, :paths => ["baz"])
    GitRepo.stub(:run!)
    GitRepo.stub(:synchronize_with_remote).and_return(true)
    GitRepo.stub(:sha_for_branch).and_return(current_repo_master)
    BuildStrategy.stub(:promote_build)
    BuildStrategy.stub(:run_success_script)
    stub_request(:post, %r{#{repository.base_api_url}/statuses})
  end

  shared_examples "a non promotable state" do
    it "should not promote the build" do
      BuildStateUpdateJob.perform(build.id)
      BuildStrategy.should_not_receive(:promote_build)
    end
  end

  describe "#perform" do
    it "updates github when a build passes" do
      states = []
      stub_request(:post, "#{repository.base_api_url}/statuses/#{build.ref}").with do |request|
        request.headers["Authorization"].should == "token #{GithubRequest::OAUTH_TOKEN}"
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
      states.should == ["pending", "success"]
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
          let(:name) { repository.repository_name }

          context "new sha is available" do
            let(:current_repo_master) { "new-sha" }

            it "builds when there is a new sha to build" do
              expect { subject }.to change(project.builds, :count).by(1)
              build = project.builds.last
              build.queue.should == :ci
              build.ref.should == "new-sha"
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
              build.queue.should == :ci
              build.ref.should == "new-sha"
            end

            it "does not kick off a new build if one is already running" do
              project.builds.create!(:ref => 'some-other-sha', :state => :partitioning, :queue => :ci, :branch => 'master')
              expect { subject }.to_not change(project.builds, :count)
            end

            it "does not roll back a builds state" do
              new_build = project.builds.create!(:ref => current_repo_master, :state => :failed, :queue => :ci, :branch => 'master')
              expect { subject }.to_not change(project.builds, :count)
              new_build.reload.state.should == :failed
            end

          end

          context "no new sha" do
            it "does not build" do
              expect { subject }.to_not change(project.builds, :count)
            end
          end
        end
      end

      it "should promote the build" do
        BuildStrategy.should_receive(:promote_build).with(build.ref, build.repository)
        BuildStrategy.should_not_receive(:run_success_script)
        BuildStateUpdateJob.perform(build.id)
      end

      context "with a success script" do
        before do
          repository.update_attribute(:on_success_script, "./this_is_a_triumph")
        end

        it "promote the build only once" do
          BuildStrategy.should_receive(:run_success_script).once.with(build.repository, build.ref, build.branch).and_return("this is a log file\n\n")
          2.times {
            BuildStateUpdateJob.perform(build.id)
          }
          build.reload.on_success_script_log_file.read.should == "this is a log file\n\n"
        end
      end

      it "should automerge the build" do
        build.update_attributes(:auto_merge => true, :queue => :developer)
        BuildStrategy.should_receive(:merge_ref).with(build)
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
