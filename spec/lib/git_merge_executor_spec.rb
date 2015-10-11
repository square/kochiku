require 'spec_helper'
require 'git_merge_executor'

describe GitMergeExecutor do
  before do
    settings = SettingsAccessor.new(<<-YAML)
    git_servers:
      github.com:
        type: github
      stash.example.com:
        type: stash
    YAML
    stub_const "Settings", settings
  end

  describe "#merge_and_push" do
    let(:build) { FactoryGirl.create(:build) }
    let(:merger) { described_class.new(build) }

    subject { merger.merge_and_push }

    context "when merge succeeds" do
      before(:each) do
        @stubber = CommandStubber.new
      end

      it "should not raise exceptions" do
        combined_log = subject
        expect(combined_log).to include(@stubber.fake_command_output)
        @stubber.check_cmd_executed("git merge")
      end
    end

    context "when merge fails due to merge conflicts" do
      before(:each) do
        @stubber = CommandStubber.new
        @stubber.stub_capture2e_failure("git merge")
      end

      it "should raise an exception" do
        expect { subject }.to raise_error(described_class::GitMergeFailedError)
      end
    end

    context "when push fails it resets the git repo and tries again" do
      before(:each) do
        status_success = double('Process::Status', :success? => true)
        allow(merger).to receive(:sleep)
        allow(Open3).to receive(:capture2e).and_return(["", status_success])
      end

      it "should raise an exception" do
        status_failure = double('Process::Status', :success? => false)
        expect(Open3).to receive(:capture2e).with(/git push/)
          .and_return(["", status_failure])
          .exactly(3).times
        expect { subject }.to raise_error(described_class::GitPushFailedError)
      end
    end
  end
end
