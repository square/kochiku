class PollRepositoriesJob
  def self.perform
    Repository.find_each do |repo|
      proj = repo.main_project
      next unless proj

      branch = proj.branch || 'master'
      head = repo.sha_for_branch(branch)
      unless repo.build_for_commit(head)
        proj.builds.create!(ref: head, state: :partitioning, branch: branch)
        Rails.logger.info "Build created for #{repo.name} at #{head}"
      end
    end
  end
end
