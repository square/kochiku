require 'spec_helper'

describe RemoteServer::Github do
  describe '#promote_branch!' do
    let(:repo) { double(project_params: {}, url: 'git@github.com:square/kochiku.git') }
    let(:server) { described_class.new(repo) }

    it 'creates branch if it does not exist' do
      expect(GithubRequest).to receive(:post) do |uri, args|
        expect(args[:ref]).to eq('refs/heads/deployable-myapp')
        expect(args[:sha]).to eq('abc123')
      end
      expect(GithubRequest).to receive(:patch) do |uri, args|
        expect(uri.to_s).to match(/deployable-myapp\Z/)
        expect(args[:force]).to eq('true')
        expect(args[:sha]).to eq('abc123')
      end
      server.promote_branch!('deployable-myapp', 'abc123')
    end

    it 'updates branch to the given ref when it already exists' do
      expect(GithubRequest)
        .to receive(:post)
        .and_raise(GithubRequest::ResponseError)
      expect(GithubRequest).to receive(:patch) do |uri, args|
        expect(uri.to_s).to match(/deployable-myapp\Z/)
        expect(args[:force]).to eq('true')
        expect(args[:sha]).to eq('abc123')
      end
      server.promote_branch!('deployable-myapp', 'abc123')
    end
  end

  describe "base_api_url" do
    describe "for github.com" do
      it "should use the api subdomain" do
        repo = Repository.new(:url => "git@github.com:square/kochiku.git")
        enterprise = RemoteServer::Github.new(repo)
        expect(enterprise.base_api_url).to eq("https://api.github.com/repos/square/kochiku")
      end
    end

    describe "for github enterprise" do
      it "should use the api path prefix" do
        repo = Repository.new(:url => "git@git.example.com:square/kochiku.git")
        enterprise = RemoteServer::Github.new(repo)
        expect(enterprise.base_api_url).to eq("https://git.example.com/api/v3/repos/square/kochiku")
      end
    end
  end

  describe '.project_params' do
    it 'raises UnknownUrl for invalid urls' do
      expect { described_class.project_params \
        "https://github.com/blah"
      }.to raise_error(UnknownUrl)
    end
  end
end
