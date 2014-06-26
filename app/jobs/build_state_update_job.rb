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

    if build.succeeded? && build.repository.has_on_success_note?
      GitRepo.inside_repo(build.repository) do
        build.add_note!
      end
    end

    if build.promotable?
      GitRepo.inside_repo(build.repository) do
        build.promote!
      end
    elsif build.merge_on_success_enabled?
      if build.mergable_by_kochiku?
        GitRepo.inside_repo(build.repository) do
          build.merge_to_master!
        end
      else
        Rails.logger.info("Build #{build.id} has merge_on_success enabled but cannot be merged.")
      end
    end

    build.send_build_status_email!
  end
end
