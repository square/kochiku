class PollRepositoriesJob
  def self.perform
    Repository.find_each do |repo|
      proj = repo.main_project
      head = repo.remote_server.sha_for_branch(proj.branch)
      unless repo.build_for_commit(head)
        proj.builds.create!(ref: head, state: :partitioning, branch: proj.branch)
        Resque.logger.info "Build created for #{repo.name} at #{head}"
      end
    end
  end
end
