require 'spec_helper'

describe GithubPostReceiveHook do
  subject { GithubPostReceiveHook.new(repository) }
  let(:repository) { FactoryGirl.create(:repository, :url => "git@git.squareup.com:square/web.git") }

  it "does not recreate the hook if it already exists" do
    stub_request(:get, "https://git.squareup.com/api/v3/repos/square/web/hooks").with do |request|
      request.headers["Authorization"].should == "token #{GithubRequest::OAUTH_TOKEN}"
      true
    end.to_return(:body => github_hooks)
    subject.subscribe!
  end

  it "creates the hook" do
    stub_request(:get, "https://git.squareup.com/api/v3/repos/square/web/hooks").with do |request|
      request.headers["Authorization"].should == "token #{GithubRequest::OAUTH_TOKEN}"
      true
    end.to_return(:body => '[]')
    stub_request(:post, "https://git.squareup.com/api/v3/repos/square/web/hooks").with do |request|
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

  def github_hooks
"[{\"active\":true,\"updated_at\":\"2012-10-09T19:02:47Z\",\"last_response\":{\"status\":\"unused\",\"message\":null,\"code\":null},\"events\":[\"pull_request\"],\"created_at\":\"2012-10-09T19:02:47Z\",\"url\":\"https://git.squareup.com/api/v3/repos/square/kochiku/hooks/78\",\"name\":\"web\",\"config\":{\"url\":\"http://localhost:3001/pull-request-builder\"},\"id\":78}]"
  end
end
