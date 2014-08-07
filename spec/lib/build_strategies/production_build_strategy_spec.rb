require "spec_helper"
# Including the production strategy is potentially dangerous but we stub out command execution.
require "#{Rails.root}/lib/build_strategies/production_build_strategy.rb"

describe BuildStrategy do
  let(:project) { FactoryGirl.create(:big_rails_project) }
  let(:build) { FactoryGirl.create(:build, :project => project) }

  before(:each) do
    CommandStubber.new # ensure Open3 is stubbed
    allow(GitRepo).to receive(:inside_repo).and_yield

    expect(Rails.application.config.action_mailer.delivery_method).to eq(:test)
  end

  describe "#merge_ref" do
    context "when auto_merge is enabled" do
      before do
        expect(GitBlame).to receive(:emails_in_branch).with(an_instance_of(Build)).and_return("the-committers@example.com")
      end

      it "should merge to master" do
        merger = object_double(GitMergeExecutor.new(build))
        expect(GitMergeExecutor).to receive(:new).and_return(merger)
        expect(merger).to receive(:merge_and_push)
        expect { BuildStrategy.merge_ref(build) }.not_to raise_error
      end

      it "should handle merge failure" do
        merger = object_double(GitMergeExecutor.new(build))
        expect(GitMergeExecutor).to receive(:new).and_return(merger)
        expect(merger).to receive(:merge_and_push).and_raise(GitMergeExecutor::GitMergeFailedError)

        expect(MergeMailer).to receive(:merge_failed).once.
          and_return(double('mailer', :deliver => nil))
        expect { BuildStrategy.merge_ref(build) }.to_not raise_error
      end
    end
  end

  describe "#promote_build" do
    subject { described_class.promote_build(build) }

    context "when the ref is an ancestor" do
      before(:each) {
        expect(described_class).to receive(:included_in_promotion_ref?).and_return(true)
      }
      it "does not perform an update" do
        expect(described_class).to_not receive(:update_branch)
        subject
      end
    end

    context "when the ref is not an ancestor" do
      before(:each) {
        expect(described_class).to receive(:included_in_promotion_ref?).and_return(false)
      }
      it "should update the promotion branch" do
        expect(described_class).to receive(:update_branch).with(project.repository.promotion_refs.first, build.ref)
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
    let (:repository) { project.repository }
    subject {
      described_class.run_success_script(build)
    }

    before do
      repository.update_attribute(:on_success_script, "./this_is_a_triumph")
      allow(GitRepo).to receive(:inside_copy).and_yield
      allow(GitRepo).to receive(:load_kochiku_yml).and_return(nil)
    end

    it "run success script only once" do
      command = double("Cocaine::CommandLine", :run => "this is some output\n", :exit_status => "255")
      allow(Cocaine::CommandLine).to receive(:new).and_return(command)
      subject
      expect(build.reload.on_success_script_log_file.read).to eq("this is some output\n\nExited with status: 255")
    end
  end
end
