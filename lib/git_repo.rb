require 'cocaine'
require 'fileutils'

class GitRepo
  class RefNotFoundError < StandardError; end

  WORKING_DIR = Rails.root.join('tmp', 'build-partition')

  class << self
    def inside_copy(repository, sha, branch = "master")
      cached_repo_path = cached_repo_for(repository)

      synchronize_cache_repo(cached_repo_path, branch)

      Dir.mktmpdir(nil, WORKING_DIR) do |dir|
        # clone local repo (fast!)
        Cocaine::CommandLine.new("git clone", "#{cached_repo_path} #{dir}").run

        Dir.chdir(dir) do
          raise RefNotFoundError, "repo:#{repository.url} branch:#{branch}, sha:#{sha}" unless system("git rev-list --quiet -n1 #{sha}")

          Cocaine::CommandLine.new("git checkout", "--quiet :commit").run(commit: sha)

          synchronize_submodules_from_cached_repo(repository, cached_repo_path)

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

    def create_working_dir
      FileUtils.mkdir_p(WORKING_DIR)
    end

    private

    def cached_repo_for(repository)
      cached_repo_path = File.join(WORKING_DIR, repository.repo_cache_name)

      if !File.directory?(cached_repo_path)
        clone_repo(repository, cached_repo_path)
      else
        harmonize_remote_url(cached_repo_path, repository.url_for_fetching)
      end

      cached_repo_path
    end

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

    def synchronize_cache_repo(cached_repo_path, branch)
      Dir.chdir(cached_repo_path) do
        # update the cached repo
        synchronize_with_remote('origin', branch)
        synchronize_submodules
      end
    end

    def clone_repo(repo, cached_repo_path)
      # Note: the --config option was added in git 1.7.7
      Cocaine::CommandLine.new(
          "git clone",
          "--recursive --config remote.origin.pushurl=#{repo.url} #{repo.url_for_fetching} #{cached_repo_path}").
          run
    end

    def synchronize_with_remote(name, branch = nil)
      # Undo this for now, partition does not seem as stable with this enabled.
      #refspec = branch.to_s.empty? ? "" : "+#{branch}"
      #Cocaine::CommandLine.new("git fetch", "--quiet --prune --no-tags #{name} #{refspec}").run
      Cocaine::CommandLine.new("git fetch", "--quiet --prune --no-tags #{name}").run
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

    def with_submodules
      return unless File.exists?('.gitmodules')

      Cocaine::CommandLine.new("git submodule", "--quiet init").run
      submodules = Cocaine::CommandLine.new('git config', '--get-regexp "^submodule\\..*\\.url$"').run

      yield submodules unless submodules.empty?
    end

    def synchronize_submodules
      with_submodules do |submodules|
        submodules.each_line do |config_line|
          submodule_path = config_line.match(/submodule\.(.*?)\.url/)[1]
          existing_url = config_line.split(" ")[1]
          begin
            submodule_url = RemoteServer.for_url(existing_url).url_for_fetching
            if existing_url != submodule_url
              Cocaine::CommandLine.new("git config",
                                       "--replace-all submodule.#{submodule_path}.url '#{submodule_url}'").run
            end
          rescue RemoteServer::UnknownGitServer
            # If the settings don't contain information about the server, don't rewrite it
          end
        end

        Cocaine::CommandLine.new('git submodule', '--quiet update').run
      end
    end

    def synchronize_submodules_from_cached_repo(repo, cached_repo_path)
      with_submodules do |submodules|
        cached_submodules = nil
        inside_repo(repo, sync: false) do
          cached_submodules = Cocaine::CommandLine.new('git config', '--get-regexp "^submodule\\..*\\.url$"').run
        end

        # Redirect the submodules to the cached_repo
        # If the submodule was added since the last time the cache was synchronized with the remote
        # then it will not be present in the cached_repo and we will use a remote url to clone
        submodules.each_line do |config_line|
          submodule_path = config_line.match(/submodule\.(.*?)\.url/)[1]
          if cached_submodules.include?(config_line)
            Cocaine::CommandLine.new("git config",
                                     "--replace-all submodule.#{submodule_path}.url '#{cached_repo_path}/#{submodule_path}'").run
          else
            existing_url = config_line.split(" ")[1]
            begin
              submodule_url = RemoteServer.for_url(existing_url).url_for_fetching
              if existing_url != submodule_url
                Cocaine::CommandLine.new("git config",
                                         "--replace-all submodule.#{submodule_path}.url '#{submodule_url}'").run
              end
            rescue RemoteServer::UnknownGitServer
              # If the settings don't contain information about the server, don't rewrite it
            end
          end
        end

        Cocaine::CommandLine.new('git submodule', '--quiet update').run
      end
    end
  end
end
