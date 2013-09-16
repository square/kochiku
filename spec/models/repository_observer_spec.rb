require 'spec_helper'

describe RepositoryObserver do
  subject { RepositoryObserver.instance }
  let(:repository) { FactoryGirl.create(:repository, :url => "git@git.example.com:square/web.git") }

  before do
    settings = SettingsAccessor.new(<<-YAML)
    git_servers:
      git.example.com:
        type: github
    YAML
    stub_const "Settings", settings

    subject.stub(:should_contact_github?).and_return(true)
  end

  it "creates the hook if enabled" do
    stub_request(:get, "#{repository.base_api_url}/hooks").with do |request|
      request.headers["Authorization"].should == "token #{GithubRequest::OAUTH_TOKEN}"
      true
    end.to_return(:body => '[]')
    stub_request(:post, "#{repository.base_api_url}/hooks").with do |request|
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
