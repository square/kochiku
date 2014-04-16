require 'spec_helper'
require 'remote_server/github'

describe RemoteServer::Github do
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

    context 'with a nonsense URL' do
      it 'raises' do
        expect {
          described_class.project_params "github.com/asdf"
        }.to raise_error(UnknownUrl)
      end
    end
  end
end
