require 'job_base'
require 'git_repo'
require 'github_commit_status'

# this job updates the remote repo. it is enqueued when a build's state changes.
class BuildStateUpdateJob < JobBase
  @queue = :high

  def initialize(build_id)
    @build_id = build_id
  end

  def perform
    build = Build.find(@build_id)

    # notify github/stash that the build status has changed
    build.update_commit_status!

    # trigger another build for this branch if there is unbuilt commits
    if build.branch_record.convergence? && build.completed?
      sha = build.repository.sha_for_branch(build.branch_record.name)
      build.branch_record.kickoff_new_build_unless_currently_busy(sha)
    end

    build.send_build_status_email!

    if build.succeeded?
      if !build.on_success_script_log_file.present? && build.on_success_script.present?
        BuildStrategy.run_success_script(build)
      end
    end

    if build.promotable?
      build.promote!
    elsif build.merge_on_success_enabled?
      if build.mergable_by_kochiku?
        # ACHTUNG merge to master isn't right anymore. This part my have been changed by shenil
        build.merge_to_master!
      else
        Rails.logger.warn("Build #{build.id} has merge_on_success enabled but cannot be merged.")
      end
    end
  end
end
