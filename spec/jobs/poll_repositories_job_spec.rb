require 'spec_helper'

describe PollRepositoriesJob do

  describe "#perform" do
    subject { PollRepositoriesJob.perform() }

    context "when scheduled to run" do

      before do
        @repo = FactoryGirl.create(:repository)
        @project = FactoryGirl.create(:main_project, :repository => @repo)
        fake_remote_server = double(:sha_for_branch => to_40("test_sha"))
        allow(RemoteServer).to receive(:for_url).with(@repo.url).and_return(fake_remote_server)
      end

      it "will build any new commit" do
        subject
        expect(Build.exists?(:ref => to_40("test_sha"), :project_id => @project.id)).to be(true)
      end

      it "won't build an old commit" do
        FactoryGirl.create(:build, :project => @project, :ref => to_40("test_sha"))
        expect { subject }.to_not change(@project.builds, :count)
      end
    end
  end
end
