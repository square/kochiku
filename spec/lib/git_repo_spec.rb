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

    it 'updates the remote URL of the cached copy if the remote URL has changed' do
      # Stipulates that the namespace and the name of the repo are still the
      # same. This is for situations where something else about the url
      # changed, e.g. switched to a git mirror

      Dir.mktmpdir do |old_remote|
        Dir.mktmpdir do |new_remote|

          Dir.chdir(old_remote) do
            `git init`
            FileUtils.touch("TESTFILE")
            `git add -A`
            `git commit -m "Initial commit"`
          end

          repository = double('Repository',
                              namespace:        'sq',
                              name:             'fun-with-flags',
                              url:              'push-url',
                              url_for_fetching: old_remote)
          # Clone the repo first time, prime the cache.
          GitRepo.inside_repo(repository, sync: false) {}

          # make a copy of the faux remote
          FileUtils.cp_r("#{old_remote}/.", new_remote, verbose: false)

          allow(repository).to receive(:url_for_fetching).and_return(new_remote)

          # retrieve the updated url of the repository
          updated_remote = nil
          GitRepo.inside_repo(repository, sync: false) do
            updated_remote = `git config --get remote.origin.url`.chomp
          end

          expect(updated_remote).to eq(new_remote)
        end
      end
    end
  end
end
