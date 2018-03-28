class PollRepositoriesJob
  def self.perform
    Branch.joins(:repository)
          .where(convergence: true, 'repositories.enabled': true)
          .includes(:repository)
          .find_each(batch_size: 20) do |branch|

      repo = branch.repository

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
