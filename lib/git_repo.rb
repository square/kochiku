class GitRepo
  WORKING_DIR="#{Rails.root}/tmp/build-partition"

  def self.inside_copy(cached_repo_name, ref = "master")

    # update local repo
    `cd #{WORKING_DIR}/#{cached_repo_name} && git fetch`

    Dir.mktmpdir(nil, WORKING_DIR) do |dir|
      Dir.chdir(dir)
        # clone local repo (fast!)
        `git clone #{WORKING_DIR}/web-cache .`

        # checkout
        `git checkout #{ref}`

        yield
      end
    end

  end
end
