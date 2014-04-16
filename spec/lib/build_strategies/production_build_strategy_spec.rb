require "spec_helper"
# Including the production strategy is potentially dangerous but we stub out command execution.
require "#{Rails.root}/lib/build_strategies/production_build_strategy.rb"

describe BuildStrategy do
  let(:project) { FactoryGirl.create(:big_rails_project) }
  let(:build) { FactoryGirl.create(:build, :project => project) }

  before(:each) do
    CommandStubber.new # ensure Open3 is stubbed

    expect(Rails.application.config.action_mailer.delivery_method).to eq(:test)
  end

  describe "#merge_ref" do
    context "when auto_merge is enabled" do
      before do
        expect(GitBlame).to receive(:emails_in_branch).with(build).and_return("the-committers@example.com")
      end

      it "should merge to master" do
        merger = GitMergeExecutor.new
        expect(GitMergeExecutor).to receive(:new).and_return(merger)
        expect(merger).to receive(:merge).with(build)
        expect(BuildStrategy.merge_ref(build)).not_to be_nil
      end

      it "should handle merge failure" do
        merger = GitMergeExecutor.new
        expect(GitMergeExecutor).to receive(:new).and_return(merger)
        expect(merger).to receive(:merge).with(build).and_raise(GitMergeExecutor::UnableToMergeError)

        expect(BuildStrategy.merge_ref(build)).not_to be_nil
      end
    end
  end

  describe "#promote_build" do
    subject { described_class.promote_build(build.ref, project.repository) }

    context "when pushing to a ref that doesn't exist" do
      before(:each) {
        mock_show_ref_command = double
        expect(mock_show_ref_command).to receive(:run).and_return "deadbeef refs/remote/origin/branch"
        allow(Cocaine::CommandLine).to receive(:new).with("git show-ref", anything, anything).and_return mock_show_ref_command

        mock_cherry_command = double
        expect(mock_cherry_command).to receive(:run).and_return "+ deadbeef"
        allow(Cocaine::CommandLine).to receive(:new).with("git cherry", "origin/#{project.repository.promotion_refs.first} #{build.ref}").and_return mock_cherry_command
      }
      it "pushes the ref" do
        expect(described_class).to receive(:promote).with(project.repository.promotion_refs.first, build.ref)
        subject
      end
    end

    context "when pushing to a ref that doesn't exist" do
      before(:each) {
        mock_git_command = double
        expect(mock_git_command).to receive(:run).and_return ""
        allow(Cocaine::CommandLine).to receive(:new).with("git show-ref", anything, anything).and_return mock_git_command
      }

      it "fails gracefully if the ref is undefined" do
        expect(described_class).to receive(:promote).with(project.repository.promotion_refs.first, build.ref)
        subject
      end
    end
  end

  describe "#promote" do
    subject {
      described_class.promote('last-green', 'abc123')
    }

    it "should promote a sha" do
      mock_git_command = double
      expect(mock_git_command).to receive(:run).and_return ""
      allow(Cocaine::CommandLine).to receive(:new).with("git push", "origin abc123:refs/heads/last-green -f").and_return mock_git_command

      subject
    end
  end
end
