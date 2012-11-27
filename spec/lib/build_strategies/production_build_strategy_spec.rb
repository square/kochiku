require "spec_helper"
# Including the production strategy is potentially dangerous but we stub out command execution.
require "#{Rails.root}/lib/build_strategies/production_build_strategy.rb"

describe BuildStrategy do
  let(:project) { FactoryGirl.create(:big_rails_project) }
  let(:build) { FactoryGirl.create(:build, :project => project, :queue => "developer") }

  before(:each) do
    CommandStubber.new # ensure Open3 is stubbed

    Rails.application.config.action_mailer.delivery_method.should == :test
  end

  describe "#merge_ref" do
    context "when auto_merge is enabled" do
      it "should merge to master" do
        merger = GitAutomerge.new
        GitAutomerge.should_receive(:new).and_return(merger)
        merger.should_receive(:automerge).with(build)
        GitBlame.should_receive(:emails_since_last_green).with(duck_type(:repository))

        BuildStrategy.merge_ref(build).should_not be_nil
      end

      it "should handle merge failure" do
        merger = GitAutomerge.new
        GitAutomerge.should_receive(:new).and_return(merger)
        merger.should_receive(:automerge).with(build).and_raise(GitAutomerge::UnableToMergeError.new)

        BuildStrategy.merge_ref(build).should_not be_nil
      end
    end
  end

  describe "#promote_build" do
    subject { described_class.promote_build(build.ref, project.repository) }

    context "when pushing to a ref that doesn't exist" do
      before(:each) {
        mock_git_command = mock()
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
      mock_git_command = mock()
      mock_git_command.should_receive(:run).and_return ""
      Cocaine::CommandLine.stub(:new).with(["git push", "origin abc123:refs/heads/last-green -f"]).and_return mock_git_command

      subject
    end
  end
end