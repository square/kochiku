require "spec_helper"
# Including the production strategy is potentially dangerous but we stub out command execution.
require "#{Rails.root}/lib/build_strategies/production_build_strategy.rb"

describe BuildStrategy do
  let(:branch) { FactoryGirl.create(:branch, name: 'funyuns') }
  let(:build) { FactoryGirl.create(:build, branch_record: branch) }

  before(:each) do
    CommandStubber.new # ensure Open3 is stubbed

    expect(Rails.application.config.action_mailer.delivery_method).to eq(:test)
  end

  describe "#merge_ref" do
    before do
      allow(GitRepo).to receive(:inside_copy).and_yield
    end

    context "when auto_merge is enabled" do
      before do
        expect(GitBlame).to receive(:emails_in_branch).with(an_instance_of(Build)).and_return("the-committers@example.com")
      end

      context "Using a github build" do
        it "should merge to master" do
          merger = object_double(GitMergeExecutor.new(build))
          expect(GitMergeExecutor).to receive(:new).and_return(merger)
          expect(merger).to receive(:merge_and_push).and_return(merge_commit: to_40('a'), log_output: "This is not a drill")
          expect(merger).to receive(:delete_branch)
          expect { BuildStrategy.merge_ref(build) }.not_to raise_error
        end

        it "should handle merge failure" do
          merger = object_double(GitMergeExecutor.new(build))
          expect(GitMergeExecutor).to receive(:new).and_return(merger)
          expect(merger).to receive(:merge_and_push).and_raise(GitMergeExecutor::GitMergeFailedError)

          expect(MergeMailer).to receive(:merge_failed).once
            .and_return(double('mailer', :deliver_now => nil))
          expect { BuildStrategy.merge_ref(build) }.to_not raise_error
        end
      end
    end

    context "Using a stash build" do
      let(:stash_branch) { FactoryGirl.create(:branch, repository: FactoryGirl.create(:stash_repository)) }
      let(:stash_build) { FactoryGirl.create(:build, branch_record: stash_branch) }

      before do
        settings = SettingsAccessor.new(<<-YAML)
          sender_email_address: kochiku@example.com
          kochiku_notifications_email_address: test@example.com
          git_servers:
            github.com:
              type: github
            stash.example.com:
              type: stash
          YAML
        stub_const "Settings", settings
      end

      it "should merge to master using stash REST api" do
        merger = object_double(GitMergeExecutor.new(stash_build))
        expect(GitMergeExecutor).to receive(:new).and_return(merger)
        expect(merger).to receive(:merge_and_push).and_return(merge_commit: to_40('a'), log_output: "This is not a drill")
        expect(merger).to receive(:delete_branch)

        expect { BuildStrategy.merge_ref(build) }.not_to raise_error
      end
    end

  end

  describe "#promote_build" do
    subject { described_class.promote_build(build) }

    before do
      allow(GitRepo).to receive(:inside_repo).and_yield
    end

    context "when the ref is an ancestor" do
      before(:each) {
        expect(GitRepo).to receive(:included_in_promotion_ref?).and_return(true)
      }
      it "does not perform an update" do
        expect(described_class).to_not receive(:update_branch)
        subject
      end
    end

    context "when the ref is not an ancestor" do
      before(:each) {
        expect(GitRepo).to receive(:included_in_promotion_ref?).and_return(false)
      }
      it "should update the promotion branch" do
        expect(described_class).to receive(:update_branch).with(branch.repository.promotion_refs.first, build.ref)
        subject
      end
    end
  end

  describe "#update_branch" do
    subject {
      described_class.update_branch('last-green', 'abc123')
    }

    it "should promote a sha" do
      mock_git_command = double
      expect(mock_git_command).to receive(:run).and_return ""
      expect(Cocaine::CommandLine).to receive(:new).with("git push", "--force origin abc123:refs/heads/last-green").and_return mock_git_command

      subject
    end
  end

  describe "#run_success_script" do
    let(:repository) { branch.repository }
    subject {
      described_class.run_success_script(build)
    }

    before do
      allow(GitRepo).to receive(:inside_copy).and_yield
      expect(build).to receive(:on_success_script).and_return("./this_is_a_triumph")
    end

    it "run success script only once" do
      command = double("Cocaine::CommandLine", :run => "this is some output\n", :exit_status => "255")
      allow(Cocaine::CommandLine).to receive(:new).and_return(command)
      subject
      expect(build.reload.on_success_script_log_file.read).to eq("this is some output\n\nExited with status: 255")
    end
  end

  describe "#on_success_command" do
    let(:repository) { branch.repository }

    before do
      allow(GitRepo).to receive(:inside_copy).and_yield
      expect(build).to receive(:on_success_script).and_return("./this_is_a_triumph")
    end

    it "sets GIT_BRANCH and GIT_COMMIT" do
      command = described_class.on_success_command(build)
      expect(command).to include("./this_is_a_triumph")
      expect(command).to include("GIT_BRANCH=")
      expect(command).to include("GIT_COMMIT=")
    end
  end
end
