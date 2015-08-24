class PollRepositoriesJob
  def self.perform
    Branch.where(convergence: true).includes(:repository).find_each do |branch|
      repo = branch.repository

      begin
        head = repo.sha_for_branch(branch.name)
      rescue RemoteServer::RefDoesNotExist, Zlib::BufError => e
        Rails.logger.info("[PollRepositoriesJob] Exception #{e.to_s} occurred for repo #{repo.id}:#{repo.name}")
        next
      end

      unless repo.build_for_commit(head)
        branch.builds.create!(ref: head, state: :partitioning)
        Rails.logger.info "Build created for #{repo.namespace}/#{repo.name}:#{branch.name} at #{head}"
      end
    end
  end
end
