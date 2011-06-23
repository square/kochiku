class GitRepo
  WORKING_DIR="#{Rails.root}/tmp/build-partition"

  def self.inside_copy(cached_repo_name, ref = "master")
    # update local repo
    run "cd #{WORKING_DIR}/#{cached_repo_name} && git fetch"

    Dir.mktmpdir(nil, WORKING_DIR) do |dir|
      Dir.chdir(dir) do
        # clone local repo (fast!)
        run "git clone #{WORKING_DIR}/web-cache ."

        # checkout
        run "git checkout #{ref}"

        yield
      end
    end
  end

  def self.run(cmd)
    system(cmd)
  end
end
