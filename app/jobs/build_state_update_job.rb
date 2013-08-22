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
    build.repository.remote_server.update_commit_status!(build)

    # trigger another build if there are new commits to build
    if build.project.main? && build.completed?
      sha = GitRepo.sha_for_branch(build.repository, "master")
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
