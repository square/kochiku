require 'spec_helper'

describe RemoteServer do
  before do
    settings = SettingsAccessor.new(<<-YAML)
    git_servers:
      stash.example.com:
        type: stash
        username: stashuser
        password_file: /password
    YAML
    stub_const "Settings", settings

    allow(File).to receive(:read).with("/password").and_return("stashpassword")
  end

  let(:repository) { FactoryGirl.create(:repository, url: 'git@stash.example.com/foo/bar.git')}
  let(:stash) { RemoteServer::Stash.new(repository) }
  let(:stash_request) { stash.stash_request }

  describe RemoteServer::StashRequest do
    describe ".setup_auth!" do
      it "should send username and password on" do
        request = double()
        expect(request).to receive(:basic_auth).with("stashuser", "stashpassword")
        stash_request.setup_auth!(request)
      end
    end
  end

  describe RemoteServer::Stash do
    describe "#update_commit_status!" do
      let(:build) { FactoryGirl.create(:build) }

      it "should post to stash" do
        stub_request(:post, "https://stashuser:stashpassword@stash.example.com/rest/build-status/1.0/commits/#{build.ref}")

        stash.update_commit_status!(build)

        WebMock.should have_requested(:post, "https://stashuser:stashpassword@stash.example.com/rest/build-status/1.0/commits/#{build.ref}")
      end
    end
  end
end