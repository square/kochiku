require 'spec_helper'

describe 'stash integration test' do
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

  let(:repository) { FactoryGirl.create(:repository, url: 'https://stash.example.com/scm/foo/bar.git')}
  let(:stash) { RemoteServer::Stash.new(repository) }
  let(:stash_request) { stash.stash_request }

  describe ".setup_auth!" do
    it "should send username and password on" do
      request = double()
      expect(request).to receive(:basic_auth).with("stashuser", "stashpassword")
      stash_request.setup_auth!(request)
    end
  end

  describe "#update_commit_status!" do
    let(:build) { double('build',
      ref:        'abc123',
      project:    double('project'),
      succeeded?: true,
      id:         123
    ) }

    it "should post to stash" do
      stub_request(:post, "https://stashuser:stashpassword@stash.example.com/rest/build-status/1.0/commits/#{build.ref}")

      stash.update_commit_status!(build)

      WebMock.should have_requested(:post, "https://stashuser:stashpassword@stash.example.com/rest/build-status/1.0/commits/#{build.ref}")
    end
  end
end

describe RemoteServer::Stash do
  describe '.project_params' do
    it 'parses HTTPS url' do
      result = described_class.project_params \
        "https://stash.example.com/scm/myproject/myrepo.git"

      expect(result).to eq(
        host:       'stash.example.com',
        username:   'myproject',
        repository: 'myrepo'
      )
    end

    it 'does not support HTTP auth credentials in URL' do
      # Use a netrc file instead.
      expect { described_class.project_params \
        "https://don@stash.example.com/scm/myproject/myrepo.git"
      }.to raise_error(UnknownUrl)
    end

    it 'does not support ssh URLs' do
      # It could support ssh URLs in the future if you wanted to implement it.
      expect { described_class.project_params \
        "ssh://git@stash.example.com:7999/myproject/myrepo.git"
      }.to raise_error(UnknownUrl)
    end
  end
end
