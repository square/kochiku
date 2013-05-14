require 'job_base'
require 'git_repo'
require 'github_commit_status'

class BuildStateUpdateJob < JobBase
  @queue = :high

  def initialize(build_id)
    @build_id = build_id
  end

  def perform
    build = Build.find(@build_id)
    previous_state, new_state = build.update_state_from_parts!
    Rails.logger.info("Build #{build.id} state is now #{build.state}")

    if previous_state != new_state
      GithubCommitStatus.new(build).update_commit_status!

      if build.project.main_build? && build.completed?
        sha = GitRepo.current_master_ref(build.repository)
        build.project.builds.create_new_ci_build_for(sha)
      end

      if build.succeeded? && build.repository.has_on_success_note?
        GitRepo.inside_repo(build.repository) do
          build.add_note!
        end
      end

      if build.promotable?
        GitRepo.inside_repo(build.repository) do
          build.promote!
        end
      elsif build.auto_merge_enabled?
        if build.auto_mergable?
          GitRepo.inside_repo(build.repository) do
            build.auto_merge!
          end
        else
          Rails.logger.info("Build #{build.id} is auto_merge enabled but cannot be auto merged.")
        end
      end

      build.send_build_status_email!
    end
  end
end
