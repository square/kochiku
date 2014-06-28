require 'spec_helper'

describe PollRepositoriesJob do

  subject { PollRepositoriesJob.perform }

  let(:repo) { FactoryGirl.create(:repository) }
  let(:project) { FactoryGirl.create(:main_project, :repository => repo) }

  before do
    fake_remote_server = double(:sha_for_branch => to_40("test_sha"))
    allow(RemoteServer).to receive(:for_url).with(repo.url).and_return(fake_remote_server)
  end

  it "will build any new commit" do
    project # force create
    subject
    expect(Build.exists?(:ref => to_40("test_sha"), :project_id => project.id)).to be(true)
  end

  it "won't build an old commit" do
    FactoryGirl.create(:build, :project => project, :ref => to_40("test_sha"))
    expect { subject }.to_not change(project.builds, :count)
  end

  it "is resilient to not having a main project" do
    expect(repo.main_project).to be_nil
    expect { subject }.to_not raise_error
  end
end
