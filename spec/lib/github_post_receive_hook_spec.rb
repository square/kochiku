require 'spec_helper'
require 'github_post_receive_hook'

describe GithubPostReceiveHook do
  subject { GithubPostReceiveHook.new(repository, 'github_oauth_token_test') }
  let(:repository) { FactoryBot.create(:repository, :url => "git@git.example.com:square/web.git") }

  before do
    settings = SettingsAccessor.new(<<-YAML)
    git_servers:
      git.example.com:
        type: github
    YAML
    stub_const "Settings", settings
  end

  it "does not recreate the hook if it already exists" do
    stub_request(:get, "https://git.example.com/api/v3/repos/square/web/hooks")
      .to_return(:body => github_hooks)
    subject.subscribe!
  end

  it "creates the hook" do
    stub_request(:get, "https://git.example.com/api/v3/repos/square/web/hooks")
      .to_return(:body => '[]')
    stub_request(:post, "https://git.example.com/api/v3/repos/square/web/hooks").with do |request|
      body = JSON.parse(request.body)
      expect(body["name"]).to eq("web")
      expect(body["events"]).to eq(['pull_request'])
      expect(body["active"]).to eq(true)
      expect(body["config"]["url"]).to eq("http://localhost:3001/pull-request-builder")
      true
    end.to_return(:body => github_hooks)
    subject.subscribe!
  end

  it "updates a repositories github_post_receive_hook_id" do
    expect(repository.github_post_receive_hook_id).to eq(nil)
    stub_request(:get, "https://git.example.com/api/v3/repos/square/web/hooks")
      .to_return(:body => github_hooks)
    subject.subscribe!
    expect(repository.github_post_receive_hook_id).to eq(78)
  end

  it "updates an existing hook" do
    repository.update_attributes!(:github_post_receive_hook_id => 78)
    called = false
    stub_request(:patch, "https://git.example.com/api/v3/repos/square/web/hooks/78").with do |request|
      body = JSON.parse(request.body)
      expect(body["name"]).to eq("web")
      expect(body["events"]).to eq(['pull_request'])
      expect(body["active"]).to eq(true)
      expect(body["config"]["url"]).to eq("http://localhost:3001/pull-request-builder")
      called = true
      true
    end.to_return(:body => github_hooks)
    subject.subscribe!
    expect(called).to be true
  end

  def github_hooks
    "[{\"active\":true,\"updated_at\":\"2012-10-09T19:02:47Z\",\"last_response\":{\"status\":\"unused\",\"message\":null,\"code\":null},\"events\":[\"pull_request\"],\"created_at\":\"2012-10-09T19:02:47Z\",\"url\":\"https://git.example.com/api/v3/repos/square/kochiku/hooks/78\",\"name\":\"web\",\"config\":{\"url\":\"http://localhost:3001/pull-request-builder\"},\"id\":78}]"
  end
end
