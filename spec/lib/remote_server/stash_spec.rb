require 'spec_helper'
require 'remote_server'
require 'remote_server/stash'

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

  let(:stash) { RemoteServer::Stash.new('https://stash.example.com/scm/foo/bar.git') }
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

      expect(WebMock).to have_requested(:post, "https://stashuser:stashpassword@stash.example.com/rest/build-status/1.0/commits/#{build.ref}")
    end
  end
end

describe RemoteServer::Stash do
  describe '#attributes' do
    it 'parses HTTPS url' do
      result = described_class.new \
        "https://stash.example.com/scm/myproject/myrepo.git"

      expect(result.attributes).to eq(
        host:                 'stash.example.com',
        repository_namespace: 'myproject',
        repository_name:      'myrepo'
      )
    end

    it 'does not support HTTP auth credentials in URL' do
      # Use a netrc file instead.
      expect { described_class.new \
        "https://don@stash.example.com/scm/myproject/myrepo.git"
      }.to raise_error(RemoteServer::UnknownUrlFormat)
    end

    it 'parses ssh URLs' do
      result = described_class.new \
        "git@stash.example.com:myproject/myrepo.git"

      expect(result.attributes).to eq(
        host:                 'stash.example.com',
        repository_namespace: 'myproject',
        repository_name:      'myrepo'
      )
    end

    it 'parses ssh URLs prefixed with ssh://' do
      result = described_class.new \
        "ssh://git@stash.example.com/myproject/myrepo.git"

      expect(result.attributes).to eq(
        host:                 'stash.example.com',
        repository_namespace: 'myproject',
        repository_name:      'myrepo'
      )
    end

    it 'parses ssh URLs with an explicit port' do
      result = described_class.new \
        "ssh://git@stash.example.com:7999/myproject/myrepo.git"

      expect(result.attributes).to eq(
        host:                 'stash.example.com',
        repository_namespace: 'myproject',
        repository_name:      'myrepo',
        port:                 '7999'
      )
    end
  end

  describe "#canonical_repository_url" do
    it 'should return a https url when given a ssh url' do
      ssh_url = "ssh://git@stash.example.com:7999/foo/bar.git"
      result = described_class.new(ssh_url).canonical_repository_url
      expect(result).to eq("https://stash.example.com/scm/foo/bar.git")
    end

    it 'should do nothing when given a https url' do
      https_url = "https://stash.example.com/scm/foo/bar.git"
      result = described_class.new(https_url).canonical_repository_url
      expect(result).to eq(https_url)
    end
  end
end
