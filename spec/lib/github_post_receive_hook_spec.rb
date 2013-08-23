require 'spec_helper'
require 'github_post_receive_hook'

describe GithubPostReceiveHook do
  subject { GithubPostReceiveHook.new(repository) }
  let(:repository) { FactoryGirl.create(:repository, :url => "git@git.example.com:square/web.git") }

  before do
    settings = SettingsAccessor.new(<<-YAML)
    git_servers:
      git.example.com:
        type: github
    YAML
    stub_const "Settings", settings
  end

  it "does not recreate the hook if it already exists" do
    stub_request(:get, "https://git.example.com/api/v3/repos/square/web/hooks").with do |request|
      request.headers["Authorization"].should == "token #{GithubRequest::OAUTH_TOKEN}"
      true
    end.to_return(:body => github_hooks)
    subject.subscribe!
  end

  it "creates the hook" do
    stub_request(:get, "https://git.example.com/api/v3/repos/square/web/hooks").with do |request|
      request.headers["Authorization"].should == "token #{GithubRequest::OAUTH_TOKEN}"
      true
    end.to_return(:body => '[]')
    stub_request(:post, "https://git.example.com/api/v3/repos/square/web/hooks").with do |request|
      request.headers["Authorization"].should == "token #{GithubRequest::OAUTH_TOKEN}"
      body = JSON.parse(request.body)
      body["name"].should == "web"
      body["events"].should == ['pull_request']
      body["active"].should == true
      body["config"]["url"].should == "http://localhost:3001/pull-request-builder"
      true
    end.to_return(:body => github_hooks)
    subject.subscribe!
  end

  it "updates a repositories github_post_receive_hook_id" do
    repository.github_post_receive_hook_id.should == nil
    stub_request(:get, "https://git.example.com/api/v3/repos/square/web/hooks").with do |request|
      request.headers["Authorization"].should == "token #{GithubRequest::OAUTH_TOKEN}"
      true
    end.to_return(:body => github_hooks)
    subject.subscribe!
    repository.github_post_receive_hook_id.should == 78
  end

  it "updates an existing hook" do
    repository.update_attributes!(:github_post_receive_hook_id => 78)
    called = false
    stub_request(:patch, "https://git.example.com/api/v3/repos/square/web/hooks/78").with do |request|
      request.headers["Authorization"].should == "token #{GithubRequest::OAUTH_TOKEN}"
      body = JSON.parse(request.body)
      body["name"].should == "web"
      body["events"].should == ['pull_request']
      body["active"].should == true
      body["config"]["url"].should == "http://localhost:3001/pull-request-builder"
      called = true
      true
    end.to_return(:body => github_hooks)
    subject.subscribe!
    called.should be_true
  end

  def github_hooks
"[{\"active\":true,\"updated_at\":\"2012-10-09T19:02:47Z\",\"last_response\":{\"status\":\"unused\",\"message\":null,\"code\":null},\"events\":[\"pull_request\"],\"created_at\":\"2012-10-09T19:02:47Z\",\"url\":\"https://git.example.com/api/v3/repos/square/kochiku/hooks/78\",\"name\":\"web\",\"config\":{\"url\":\"http://localhost:3001/pull-request-builder\"},\"id\":78}]"
  end
end
