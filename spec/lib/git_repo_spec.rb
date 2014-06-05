require 'spec_helper'

describe GitRepo do
  before do
    settings = SettingsAccessor.new(<<-YAML)
    git_servers:
      git.example.com:
        type: github
    YAML
    stub_const "Settings", settings
  end

  let(:repository) { FactoryGirl.create(:repository, url: 'git@git.example.com:square/web.git') }
  let(:repo_uri) { repository.base_api_url }
  let(:branch) { "test/branch" }
  let(:branch_head_sha) { "4b41fe773057b2f1e2063eb94814d32699a34541" }

  before do
    build_ref_info = <<RESPONSE
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

  describe "#synchronize_with_remote" do
    it "should throw an exception after the third fetch attempt" do
      fetch_double = double('git fetch')
      expect(fetch_double).to receive(:run).exactly(3).times.and_raise(Cocaine::ExitStatusError)
      allow(Cocaine::CommandLine).to receive(:new).with('git fetch', anything) { fetch_double }
      expect(GitRepo).to receive(:sleep).exactly(2).times
      expect { GitRepo.send(:synchronize_with_remote, "master") }.to raise_error(Cocaine::ExitStatusError)
    end
  end

  describe '#inside_repo' do
    before do
      FileUtils.rm_rf GitRepo::WORKING_DIR
      FileUtils.mkdir GitRepo::WORKING_DIR
    end

    it 'does not use a cached copy if remote URL has changed' do
      Dir.mktmpdir do |old_remote|
        Dir.mktmpdir do |new_remote|

          Dir.chdir(old_remote) do
            `git init`
            FileUtils.touch("TESTFILE")
            `git add -A`
            `git commit -m "Initial commit"`
          end

          repository = double('Repository',
            repo_cache_name:  'test-repo',
            url:              'push-url',
            url_for_fetching: old_remote
          )
          # Clone the repo first time, prime the cache.
          GitRepo.inside_repo(repository) {}

          `git clone -q #{old_remote} #{new_remote}`

          repository = double('Repository',
            repo_cache_name:  'test-repo',
            url:              'push-url',
            url_for_fetching: new_remote
          )

          actual_remote = nil

          # Same repository, different URL.
          GitRepo.inside_repo(repository) do
            actual_remote = `git config --get remote.origin.url`.chomp
          end

          expect(actual_remote).to eq(new_remote)
        end
      end
    end
  end
end
