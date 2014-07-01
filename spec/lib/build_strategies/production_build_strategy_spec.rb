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
end
