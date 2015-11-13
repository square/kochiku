require 'cocaine'
require 'fileutils'

class GitRepo
  class RefNotFoundError < StandardError; end

  WORKING_DIR = Rails.root.join('tmp', 'build-partition')

  class << self
    def inside_copy(repository, sha)
      cached_repo_path = cached_repo_for(repository)

      synchronize_cache_repo(cached_repo_path)

      Dir.mktmpdir(nil, WORKING_DIR) do |dir|
        Cocaine::CommandLine.new("git clone", "--config remote.origin.pushurl=#{repository.url} #{cached_repo_path} #{dir}").run

        Dir.chdir(dir) do
          raise RefNotFoundError, "repo:#{repository.url}, sha:#{sha}" unless system("git rev-list --quiet -n1 #{sha}")

          Cocaine::CommandLine.new("git checkout", "--quiet :commit").run(commit: sha)

          yield dir
        end
      end
    end

    def inside_repo(repository, sync: true)
      cached_repo_path = cached_repo_for(repository)

      Dir.chdir(cached_repo_path) do
        synchronize_with_remote('origin') if sync

        yield
      end
    end

    def load_kochiku_yml(repository, ref)
      inside_repo(repository) do
        raise RefNotFoundError, "repo:#{repository.url}, sha:#{ref}" unless system("git rev-list --quiet -n1 #{ref}")

        read_repo_config(ref)
      end
    end

    def included_in_promotion_ref?(build_ref, promotion_ref)
      # --is-ancestor was added in git 1.8.0
      # exit ->   1: not an ancestor
      # exit -> 128: the commit does not exist
      ancestor_cmd = Cocaine::CommandLine.new("git merge-base", "--is-ancestor #{build_ref} #{promotion_ref}", :expected_outcodes => [0, 1, 128])
      ancestor_cmd.run
      ancestor_cmd.exit_status == 0
    end

    private

    KOCHIKU_YML_LOCS = [
      'kochiku.yml',
      'config/kochiku.yml',
      'config/ci/kochiku.yml',
    ]

    def read_repo_config(ref)
      command = Cocaine::CommandLine.new("git show", ":ref::file",
                                         { :swallow_stderr => true, :expected_outcodes => [0, 128] })
      KOCHIKU_YML_LOCS.each do |loc|
        file = command.run(:ref => ref, :file => loc)
        return YAML.load(file) if command.exit_status == 0
      end
      nil
    end

    def cached_repo_for(repository)
      cached_repo_path = WORKING_DIR.join(repository.namespace, "#{repository.name}.git")

      if !cached_repo_path.directory?
        FileUtils.mkdir_p(WORKING_DIR.join(repository.namespace))
        clone_bare_repo(repository, cached_repo_path)
      else
        harmonize_remote_url(cached_repo_path, repository.url_for_fetching)
      end

      cached_repo_path
    end

    # Update the remote url for the git repository if it has changed
    def harmonize_remote_url(cached_repo_path, expected_url)
      Dir.chdir(cached_repo_path) do
        remote_url = Cocaine::CommandLine.new("git config", "--get remote.origin.url").run.chomp
        if remote_url != expected_url
          Rails.logger.info "#{remote_url.inspect} does not match #{expected_url.inspect}. Updating it."
          Cocaine::CommandLine.new("git remote", "set-url origin #{expected_url}").run
        end
      end
      nil
    end

    def synchronize_cache_repo(cached_repo_path)
      Dir.chdir(cached_repo_path) do
        # update the cached repo
        synchronize_with_remote('origin')
      end
    end

    def clone_bare_repo(repo, cached_repo_path)
      # Note: the --config option was added in git 1.7.7
      Cocaine::CommandLine.new(
        "git clone",
        "--bare --quiet --config remote.origin.pushurl=#{repo.url} --config remote.origin.fetch='+refs/heads/*:refs/heads/*' --config remote.origin.tagopt='--no-tags' #{repo.url_for_fetching} #{cached_repo_path}"
      ).run
    end

    def synchronize_with_remote(name)
      Cocaine::CommandLine.new("git fetch", "--quiet --prune #{name}").run
    rescue Cocaine::ExitStatusError => e
      # likely caused by another 'git fetch' that is currently in progress. Wait a few seconds and try again
      tries = (tries || 0) + 1
      if tries < 3
        Rails.logger.warn(e)
        sleep(15 * tries)
        retry
      else
        raise e
      end
    end
  end
end
