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
    build.update_commit_status!

    # trigger another build if there are new commits to build
    if build.project.main? && build.completed?
      sha = build.repository.sha_for_branch("master")
      build.project.builds.create_new_build_for(sha)
    end

    if build.succeeded?
      if build.on_success_script.present? && !build.on_success_script_log_file.present?
        BuildStrategy.run_success_script(build)
      end
    end

    if build.promotable?
      build.promote!
    elsif build.merge_on_success_enabled?
      if build.mergable_by_kochiku?
        build.merge_to_master!
      else
        Rails.logger.info("Build #{build.id} has merge_on_success enabled but cannot be merged.")
      end
    end

    build.send_build_status_email!
  end
end
