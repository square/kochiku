require "spec_helper"
# Including the production strategy is potentially dangerous but we stub out command execution.
require "#{Rails.root}/lib/build_strategies/production_build_strategy.rb"

describe BuildStrategy do
  let(:project) { FactoryGirl.create(:big_rails_project) }
  let(:build) { FactoryGirl.create(:build, :project => project) }

  before(:each) do
    CommandStubber.new # ensure Open3 is stubbed

    Rails.application.config.action_mailer.delivery_method.should == :test
  end

  describe "#merge_ref" do
    context "when auto_merge is enabled" do
      before do
        GitBlame.should_receive(:emails_in_branch).with(build).and_return("the-committers@example.com")
      end

      it "should merge to master" do
        merger = GitMergeExecutor.new
        GitMergeExecutor.should_receive(:new).and_return(merger)
        merger.should_receive(:merge).with(build)
        BuildStrategy.merge_ref(build).should_not be_nil
      end

      it "should handle merge failure" do
        merger = GitMergeExecutor.new
        GitMergeExecutor.should_receive(:new).and_return(merger)
        merger.should_receive(:merge).with(build).and_raise(GitMergeExecutor::UnableToMergeError)

        BuildStrategy.merge_ref(build).should_not be_nil
      end
    end
  end

  describe "#promote_build" do
    subject { described_class.promote_build(build.ref, project.repository) }

    context "when pushing to a ref that doesn't exist" do
      before(:each) {
        mock_git_command = double
        mock_git_command.should_receive(:run).and_return ""
        Cocaine::CommandLine.stub(:new).with("git show-ref", anything, anything).and_return mock_git_command
      }

      it "fails gracefully if the ref is undefined" do
        described_class.should_receive(:promote).with(:tag, project.repository.promotion_refs.first, build.ref)
        subject
      end
    end
  end

  describe "#promote" do
    subject {
      described_class.promote(:branch, 'last-green', 'abc123',)
    }

    it "should promote a sha" do
      mock_git_command = double
      mock_git_command.should_receive(:run).and_return ""
      Cocaine::CommandLine.stub(:new).with(["git push", "origin abc123:refs/heads/last-green -f"]).and_return mock_git_command

      subject
    end
  end
end
