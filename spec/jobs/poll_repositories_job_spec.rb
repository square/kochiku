require 'spec_helper'

describe PollRepositoriesJob do

  subject { PollRepositoriesJob.perform }

  let(:repo) { branch.repository }
  let!(:branch) { FactoryGirl.create(:convergence_branch) }

  before do
    fake_remote_server = double(:sha_for_branch => to_40("test_sha"))
    allow(RemoteServer).to receive(:for_url).with(repo.url).and_return(fake_remote_server)
  end

  it "will build any new commit" do
    subject
    expect(Build.exists?(:ref => to_40("test_sha"), :branch_id => branch.id)).to be(true)
  end

  it "won't build an old commit" do
    FactoryGirl.create(:build, :branch_record => branch, :ref => to_40("test_sha"))
    expect { subject }.to_not change{ branch.reload.builds.count }
  end
end
