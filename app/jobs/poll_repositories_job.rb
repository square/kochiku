class PollRepositoriesJob
  def self.perform
    Repository.where(enabled: true).find_each(batch_size: 10) do |repo|
      branch = repo.convergence_branches.first || repo.branches.where(name: 'master').first

      if branch.nil?
        Rails.logger.warn("[PollRepositoriesJob] Could not find a branch to check for repo #{repo.name_with_namespace}")
      end

      begin
        head = repo.sha_for_branch(branch.name)
      rescue RemoteServer::AccessDenied, RemoteServer::RefDoesNotExist, Zlib::BufError => e
        Rails.logger.error("[PollRepositoriesJob] Exception #{e} occurred for repo #{repo.id}:#{repo.name_with_namespace}. Automatically setting the repository to disabled.")
        repo.update!(enabled: false)
        next
      end

      unless repo.build_for_commit(head)
        branch.builds.create!(ref: head, state: 'partitioning')
        Rails.logger.info "Build created for #{repo.namespace}/#{repo.name}:#{branch.name} at #{head}"
      end

      sleep 0.5 # take a breath
    end
  end
end
