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

  let(:url) { 'https://stash.example.com/scm/foo/bar.git' }
  let(:stash) { RemoteServer::Stash.new(url, Settings.git_server(url)) }
  let(:stash_request) { stash.stash_request }

  describe ".setup_auth!" do
    it "should send username and password on" do
      request = double
      expect(request).to receive(:basic_auth).with("stashuser", "stashpassword")
      stash_request.setup_auth!(request)
    end
  end

  describe "#update_commit_status!" do
    let(:build) {
      double('build',
             ref:        'abc123',
             repository: double('repository', to_param: 'my_namespace/my_repo_name'),
             succeeded?: true,
             id:         123)
    }

    it "should post to stash" do
      stub_request(:post, "https://stashuser:stashpassword@stash.example.com/rest/build-status/1.0/commits/#{build.ref}")

      stash.update_commit_status!(build)

      expect(WebMock).to have_requested(:post, "https://stashuser:stashpassword@stash.example.com/rest/build-status/1.0/commits/#{build.ref}")
    end
  end
end

describe RemoteServer::Stash do
  def make_server(url)
    described_class.new(url, Settings.git_server(url))
  end

  describe '#attributes' do
    it 'parses HTTPS url' do
      result = make_server \
        "https://stash.example.com/scm/myproject/myrepo.git"

      expect(result.attributes).to eq(
        host:                 'stash.example.com',
        repository_namespace: 'myproject',
        repository_name:      'myrepo',
        possible_hosts:       ['stash.example.com']
      )
    end

    it 'does not support HTTP auth credentials in URL' do
      # Use a netrc file instead.
      expect {
        make_server \
          "https://don@stash.example.com/scm/myproject/myrepo.git"
      }.to raise_error(RemoteServer::UnknownUrlFormat)
    end

    it 'parses ssh URLs' do
      result = make_server \
        "git@stash.example.com:myproject/myrepo.git"

      expect(result.attributes).to eq(
        host:                 'stash.example.com',
        repository_namespace: 'myproject',
        repository_name:      'myrepo',
        possible_hosts:       ['stash.example.com']
      )
    end

    it 'parses ssh URLs prefixed with ssh://' do
      result = make_server \
        "ssh://git@stash.example.com/myproject/myrepo.git"

      expect(result.attributes).to eq(
        host:                 'stash.example.com',
        repository_namespace: 'myproject',
        repository_name:      'myrepo',
        possible_hosts:       ['stash.example.com']
      )
    end

    it 'parses ssh URLs with an explicit port' do
      result = make_server \
        "ssh://git@stash.example.com:7999/myproject/myrepo.git"

      expect(result.attributes).to eq(
        host:                 'stash.example.com',
        repository_namespace: 'myproject',
        repository_name:      'myrepo',
        port:                 '7999',
        possible_hosts:       ['stash.example.com']
      )
    end

    it 'should allow periods, hyphens, and underscores in repository names' do
      result = make_server("git@stash.example.com:angular/an-gu_lar.js.git")
      expect(result.attributes[:repository_name]).to eq('an-gu_lar.js')

      result = make_server("ssh://git@stash.example.com/angular/an-gu_lar.js.git")
      expect(result.attributes[:repository_name]).to eq('an-gu_lar.js')

      result = make_server("https://stash.example.com/scm/angular/an-gu_lar.js.git")
      expect(result.attributes[:repository_name]).to eq('an-gu_lar.js')
    end

    it 'should not allow characters disallowed by Github in repository names' do
      %w(! @ # $ % ^ & * ( ) = + \ | ` ~ [ ] { } : ; ' " ? /).each do |symbol|
        expect {
          make_server("git@stash.example.com:angular/bad#{symbol}name.git")
        }.to raise_error(RemoteServer::UnknownUrlFormat)

        expect {
          make_server("ssh://git@stash.example.com/angular/bad#{symbol}name.git")
        }.to raise_error(RemoteServer::UnknownUrlFormat)

        expect {
          make_server("https://stash.example.com/scm/angular/bad#{symbol}name.git")
        }.to raise_error(RemoteServer::UnknownUrlFormat)
      end
    end
  end

  describe "#canonical_repository_url" do
    it 'should return a https url when given a ssh url' do
      ssh_url = "ssh://git@stash.example.com:7999/foo/bar.git"
      result = make_server(ssh_url).canonical_repository_url
      expect(result).to eq("https://stash.example.com/scm/foo/bar.git")
    end

    it 'should do nothing when given a https url' do
      https_url = "https://stash.example.com/scm/foo/bar.git"
      result = make_server(https_url).canonical_repository_url
      expect(result).to eq(https_url)
    end
  end

  describe "#merge" do
    it 'uses stash API' do
      https_url = "https://stash.example.com/scm/foo/bar.git"
      server = make_server(https_url)

      allow(server).to receive(:get_pr_id_and_version).and_return([1, 5])
      allow(server).to receive(:can_merge?).and_return(true)
      allow(server).to receive(:perform_merge).and_return(true)

      expect(server).to receive(:get_pr_id_and_version).once
      expect(server).to receive(:can_merge?).once
      expect(server).to receive(:perform_merge).once

      expect { server.merge("abranch") }.to_not raise_error
    end
  end

  describe '#open_pull_request_url' do
    it 'should return the expected url' do
      https_url = "https://stash.example.com/scm/foo/bar.git"
      result = make_server(https_url).open_pull_request_url('my-new-branch')
      expect(result).to eq("https://stash.example.com/projects/FOO/repos/bar/compare/commits?sourceBranch=refs/heads/my-new-branch")
    end
  end

  describe "#head_commit" do
    let(:https_url) { "https://stash.example.com/scm/foo/bar.git" }
    let(:server) { make_server(https_url) }
    let(:stash_request) { server.stash_request }

    it "should not raise errors" do
      allow(server).to receive(:get_pr_id_and_version).and_return([1, 5])
      allow(stash_request).to receive(:get).and_return({"values" => [{"id" => "3" * 40}]}.to_json)

      expect(server).to receive(:get_pr_id_and_version).once
      expect { server.head_commit("a/branch") }.to_not raise_error
    end
  end
end
