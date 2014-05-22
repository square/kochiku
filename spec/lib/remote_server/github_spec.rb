require 'spec_helper'
require 'remote_server'
require 'remote_server/github'

describe RemoteServer::Github do
  describe "base_api_url" do
    describe "for github.com" do
      it "should use the api subdomain" do
        url = "git@github.com:square/kochiku.git"
        enterprise = RemoteServer::Github.new(url)
        expect(enterprise.base_api_url).to eq("https://api.github.com/repos/square/kochiku")
      end
    end

    describe "for github enterprise" do
      it "should use the api path prefix" do
        url = "git@git.example.com:square/kochiku.git"
        enterprise = RemoteServer::Github.new(url)
        expect(enterprise.base_api_url).to eq("https://git.example.com/api/v3/repos/square/kochiku")
      end
    end
  end

  describe '#attributes' do
    it 'raises UnknownUrlFormat for invalid urls' do
      expect {
        described_class.new("https://github.com/blah")
      }.to raise_error(RemoteServer::UnknownUrlFormat)

      expect {
        described_class.new("github.com/asdf")
      }.to raise_error(RemoteServer::UnknownUrlFormat)
    end

    it 'parses ssh URLs' do
      result = described_class.new \
        "git@github.com:who/myrepo.git"

      expect(result.attributes).to eq(
        host:                 'github.com',
        repository_namespace: 'who',
        repository_name:      'myrepo'
      )
    end

    it 'parses git:// URLs' do
      result = described_class.new \
        "git://github.com/who/myrepo.git"

      expect(result.attributes).to eq(
        host:                 'github.com',
        repository_namespace: 'who',
        repository_name:      'myrepo'
      )
    end

    it 'parses HTTPS URLs' do
      result = described_class.new \
        "https://git.example.com/who/myrepo.git"

      expect(result.attributes).to eq(
        host:                 'git.example.com',
        repository_namespace: 'who',
        repository_name:      'myrepo'
      )
    end

    it 'should allow periods, hyphens, and underscores in repository names' do
      result = described_class.new("git@github.com:angular/an-gu_lar.js.git")
      expect(result.attributes[:repository_name]).to eq('an-gu_lar.js')

      result = described_class.new("git://github.com/angular/an-gu_lar.js.git")
      expect(result.attributes[:repository_name]).to eq('an-gu_lar.js')

      result = described_class.new("https://github.com/angular/an-gu_lar.js.git")
      expect(result.attributes[:repository_name]).to eq('an-gu_lar.js')
    end

    it 'should not allow characters disallowed by Github in repository names' do
      %w(! @ # $ % ^ & * ( ) = + \ | ` ~ [ ] { } : ; ' " ?).each do |symbol|
        expect {
          described_class.new("git@github.com:angular/bad#{symbol}name.git")
        }.to raise_error(RemoteServer::UnknownUrlFormat)

        expect {
          described_class.new("git://github.com/angular/bad#{symbol}name.git")
        }.to raise_error(RemoteServer::UnknownUrlFormat)

        expect {
          described_class.new("https://github.com/angular/bad#{symbol}name.git")
        }.to raise_error(RemoteServer::UnknownUrlFormat)
      end
    end
  end

  describe '#canonical_repository_url' do
    it 'should return a ssh url when given a https url' do
      https_url = "https://github.com/square/test-repo1.git"
      result = described_class.new(https_url).canonical_repository_url
      expect(result).to eq("git@github.com:square/test-repo1.git")
    end

    it 'should do nothing when given a ssh url' do
      ssh_url = "git@github.com:square/test-repo1.git"
      result = described_class.new(ssh_url).canonical_repository_url
      expect(result).to eq(ssh_url)
    end
  end
end
