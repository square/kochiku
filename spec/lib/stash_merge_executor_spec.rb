require 'spec_helper'
require 'stash_merge_executor'

describe StashMergeExecutor do
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

  context "Using stash repository" do
    let(:stash_project) { FactoryGirl.create(:stash_project, :name => "web-pull_requests") }
    let(:stash_build) { FactoryGirl.create(:build, :project => stash_project, :branch => 'funyuns') }
    let(:stash_merger) { described_class.new(stash_build) }

    subject { stash_merger.merge_and_push }

    it "should use stash REST api" do
      expect(stash_build.repository.remote_server).to receive(:merge).once
      allow(stash_build.repository.remote_server).to receive(:merge).and_return(true)

      expect(subject).to eq("Successfully merged funyuns")
    end

    it "should use throw exception if stash api refuses merge" do
      expect(stash_build.repository.remote_server).to receive(:merge).once
      allow(stash_build.repository.remote_server).to receive(:merge).and_return(false)

      expect { subject }.to raise_error(StashMergeExecutor::GitMergeFailedError)
    end

    it "should use fall back to traditional method on stash api error" do
      @stubber = CommandStubber.new
      expect(stash_build.repository.remote_server).to receive(:merge).once
      allow(stash_build.repository.remote_server).to receive(:merge).and_raise(RemoteServer::StashAPIError)

      combined_log = subject

      expect(combined_log).to include(@stubber.fake_command_output)
      @stubber.check_cmd_executed("git merge")
    end

    context "Not a pull request" do
      before do
        stash_project.name = "web"
        @stubber = CommandStubber.new
      end

      it "should use not stash REST api" do
        expect(stash_build.repository.remote_server).to_not receive(:merge)
        combined_log = subject
        expect(combined_log).to include(@stubber.fake_command_output)
        @stubber.check_cmd_executed("git merge")
      end
    end
  end

  describe "#delete" do
    let(:stash_project) { FactoryGirl.create(:stash_project, :name => "web-pull_requests") }
    let(:stash_build) { FactoryGirl.create(:build, :project => stash_project, :branch => 'funyuns') }
    let(:stash_merger) { described_class.new(stash_build) }

    context "Using stash repository" do
      it "should use stash REST api" do
        expect(stash_build.repository.remote_server).to receive(:delete_branch).once
        allow(stash_build.repository.remote_server).to receive(:delete_branch).and_return(true)

        expect { stash_merger.delete_branch }.to_not raise_error
      end
    end
  end
end
