class GitRepo
  WORKING_DIR="#{Rails.root}/tmp/build-partition"

  class << self
    def inside_copy(cached_repo_name, ref = "master", submodules = false)
      # update local repo
      run! "cd #{WORKING_DIR}/#{cached_repo_name} && git fetch"

      Dir.mktmpdir(nil, WORKING_DIR) do |dir|
        Dir.chdir(dir) do
          # clone local repo (fast!)
          run! "git clone #{WORKING_DIR}/web-cache ."

          # checkout
          run! "git checkout #{ref}"
          run! "git submodule update --init" if submodules

          yield
        end
      end
    end

    def run!(cmd)
      unless system(cmd)
        raise "non-0 exit code #{$?} returned from [#{cmd}]"
      end
    end

    def create_working_dir
      FileUtils.mkdir_p(WORKING_DIR)
    end
  end
end
