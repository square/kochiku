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

  let(:repository) { FactoryGirl.create(:stash_repository) }
  let(:branch) { FactoryGirl.create(:branch, repository: repository, name: 'funyuns') }
  let(:stash_build) { FactoryGirl.create(:build, branch_record: branch) }
  let(:stash_merger) { described_class.new(stash_build) }

  context "Using stash repository" do
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

    context "for a build on a convergence branch" do
      let(:branch) { FactoryGirl.create(:convergence_branch, repository: repository) }

      it "should do nothing" do
        expect(stash_build.repository.remote_server).to_not receive(:merge)
        subject
      end
    end
  end

  describe "#delete" do
    context "Using stash repository" do
      it "should use stash REST api" do
        expect(stash_build.repository.remote_server).to receive(:delete_branch).once
        allow(stash_build.repository.remote_server).to receive(:delete_branch).and_return(true)

        expect { stash_merger.delete_branch }.to_not raise_error
      end
    end
  end
end
