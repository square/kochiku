require 'spec_helper'
require 'remote_server'
require 'remote_server/github'
require 'remote_server/stash'

shared_examples_for 'a remote server' do
  describe "#sha_for_branch" do
    let(:url) { good_url }
    let(:repo_uri) { remote_server.base_api_url }
    let(:branch) { "test/branch" }
    let(:branch_head_sha) { "4b41fe773057b2f1e2063eb94814d32699a34541" }

    let(:subject) { remote_server.sha_for_branch(branch) }

    it "returns the HEAD SHA for the branch" do
      expect(subject).to eq(branch_head_sha)
    end

    context "with a non-existent repo" do
      let(:url) { bad_url }

      before do
        stub_request(:get, "#{repo_uri}/git/refs/heads/#{branch}").to_return(:status => 404, :body => '{ "message": "Not Found" }')
        stub_request(:get, "https://stashuser:stashpassword@stash.example.com/rest/api/1.0/projects/sq/repos/non-existent-repo/commits?limit=1&until=#{branch}")
          .to_return(:status => 404, :body => '{ "errors": [ { "context": null, "message": "A detailed error message.", "exceptionName": null } ] }')
      end

      it "raises RepositoryDoesNotExist" do
        expect{subject}.to raise_error(RemoteServer::RefDoesNotExist)
      end
    end

    context "with a non-existent branch" do
      let(:branch) { "nonexistant-branch" }

      before do
        stub_request(:get, "#{repo_uri}/git/refs/heads/#{branch}").to_return(:status => 404, :body => '{ "message": "Not Found" }')
        stub_request(:get, "https://stashuser:stashpassword@stash.example.com/rest/api/1.0/projects/sq/repos/kochiku/commits?limit=1&until=#{branch}")
          .to_return(:status => 400, :body => '{ "errors": [ { "context": null, "message": "A detailed error message.", "exceptionName": null } ] }')
      end

      it "raises BranchDoesNotExist" do
        expect{subject}.to raise_error(RemoteServer::RefDoesNotExist)
      end
    end
  end
end

describe 'RemoteServer::GitHub' do
  let(:good_url) { 'git@git.example.com:square/kochiku.git' }
  let(:bad_url) { 'git@git.example.com:square/non-existent-repo.git' }

  before do
    settings = SettingsAccessor.new(<<-YAML)
      git_servers:
        git.example.com:
          type: github
    YAML
    stub_const "Settings", settings

    build_ref_info = <<-RESPONSE
      {
        "ref": "refs/heads/#{branch}",
        "url": "#{repo_uri}/git/refs/heads/#{branch}",
        "object": {
          "sha": "#{branch_head_sha}",
          "type": "commit",
          "url": "#{repo_uri}/git/commits/#{branch_head_sha}"
        }
      }
    RESPONSE

    stub_request(:get, "#{repo_uri}/git/refs/heads/#{branch}").to_return(:status => 200, :body => build_ref_info)
  end

  it_behaves_like 'a remote server' do
    let(:remote_server) { RemoteServer::Github.new(url, Settings.git_server(url)) }
  end
end

describe 'RemoteServer::Stash' do
  let(:good_url) { 'ssh://git@stash.example.com/sq/kochiku.git' }
  let(:bad_url) { 'ssh://git@stash.example.com/sq/non-existent-repo.git' }

  before do
    settings = SettingsAccessor.new(<<-YAML)
    git_servers:
      stash.example.com:
        type: stash
        username: stashuser
        password_file: /password
    YAML
    stub_const "Settings", settings

    build_ref_info = <<-RESPONSE
    {
        "size": 3,
        "limit": 3,
        "isLastPage": false,
        "values": [
        {
            "id": "#{branch_head_sha}"
        }
        ],
        "start": 0,
        "filter": null,
        "nextPageStart": 3
    }
    RESPONSE

    allow(File).to receive(:read).with("/password").and_return("stashpassword")

    stub_request(:get, "https://stashuser:stashpassword@stash.example.com/rest/api/1.0/projects/sq/repos/kochiku/commits?limit=1&until=#{branch}")
      .to_return(:status => 200, :body => build_ref_info)
  end

  it_behaves_like 'a remote server' do
    let(:remote_server) { RemoteServer::Stash.new(url, Settings.git_server(url)) }
  end
end

describe 'valid_git_host?' do
  before do
    settings = SettingsAccessor.new(<<-YAML)
    git_servers:
      git.example.com:
        type: github
    YAML
    stub_const "Settings", settings
  end

  it 'returns true for known git hosts' do
    known_git_host = 'git.example.com'
    expect(RemoteServer.valid_git_host?(known_git_host)).to be_truthy
  end

  it 'returns false for unknown git hosts' do
    unknown_git_host = 'example.com'
    expect(RemoteServer.valid_git_host?(unknown_git_host)).to be_falsey
  end
end
