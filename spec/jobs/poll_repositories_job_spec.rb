require 'spec_helper'

describe PollRepositoriesJob do

  subject { PollRepositoriesJob.perform }

  let(:repo) { branch.repository }
  let!(:branch) { FactoryBot.create(:convergence_branch) }

  before do
    allow(described_class).to receive(:sleep).and_return(nil)

    @fake_remote_server = double(:sha_for_branch => to_40("test_sha"))
    allow(RemoteServer).to receive(:for_url).with(repo.url).and_return(@fake_remote_server)
  end

  it "will build any new commit" do
    subject
    expect(Build.exists?(:ref => to_40("test_sha"), :branch_id => branch.id)).to be(true)
  end

  it "won't build an old commit" do
    FactoryBot.create(:build, :branch_record => branch, :ref => to_40("test_sha"))
    expect { subject }.to_not change{ branch.reload.builds.count }
  end

  # this likely means the repo has moved/renamed and the url needs to be
  # updated or has been deleted from the git server
  it "disables the repo in Kochiku if the RemoteServer returns a 404" do
    allow(@fake_remote_server).to receive(:sha_for_branch).and_raise(RemoteServer::RefDoesNotExist)
    expect { subject }.to change { repo.reload.enabled? }.from(true).to(false)
  end
end
