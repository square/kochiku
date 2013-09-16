require 'spec_helper'

describe RemoteServer::Github do
  describe '#promote_branch!' do
    let(:repo) { double(project_params: {}, url: 'git@github.com:square/kochiku.git') }
    let(:server) { described_class.new(repo) }

    it 'creates branch if it does not exist' do
      GithubRequest.should_receive(:post).with do |uri, args|
        args[:ref] == 'refs/heads/deployable-myapp' &&
          args[:sha] == 'abc123'
      end
      GithubRequest.should_receive(:patch).with do |uri, args|
        uri.to_s.should =~ /deployable-myapp\Z/ &&
          args[:force] == "true" &&
          args[:sha] == 'abc123'
      end
      server.promote_branch!('deployable-myapp', 'abc123')
    end

    it 'updates branch to the given ref when it already exists' do
      GithubRequest
        .should_receive(:post)
        .and_raise(GithubRequest::ResponseError)
      GithubRequest.should_receive(:patch).with do |uri, args|
        uri.to_s.should =~ /deployable-myapp\Z/ &&
          args[:force] == "true" &&
          args[:sha] == 'abc123'
      end
      server.promote_branch!('deployable-myapp', 'abc123')
    end
  end

  describe "base_api_url" do
    describe "for github.com" do
      it "should use the api subdomain" do
        repo = Repository.new(:url => "git@github.com:square/kochiku.git")
        enterprise = RemoteServer::Github.new(repo)
        enterprise.base_api_url.should == "https://api.github.com/repos/square/kochiku"
      end
    end

    describe "for github enterprise" do
      it "should use the api path prefix" do
        repo = Repository.new(:url => "git@git.example.com:square/kochiku.git")
        enterprise = RemoteServer::Github.new(repo)
        enterprise.base_api_url.should == "https://git.example.com/api/v3/repos/square/kochiku"
      end
    end
  end
end
