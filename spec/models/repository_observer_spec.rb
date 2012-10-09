require 'spec_helper'

describe RepositoryObserver do
  subject { RepositoryObserver.instance }
  let(:repository) { FactoryGirl.create(:repository, :url => "git@git.squareup.com:square/web.git") }

  before do
    subject.stub(:should_contact_github?).and_return(true)
  end

  it "creates the hook if enabled" do
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
      true
    end.to_return(:body => '[]')
    repository.build_pull_requests = true
    subject.after_save(repository)
  end
end
