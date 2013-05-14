require 'job_base'
require 'git_repo'
require 'github_commit_status'

# this job updates the remote repo. it is enqueued when a build's state
# changes. the change is observed in BuildAttemptObserver
class BuildStateUpdateJob < JobBase
  @queue = :high

  def initialize(build_part_id)
    @build_part_id = build_part_id
  end

  def build
    @build ||= build_part.build_instance
  end

  def build_part
    @build_part ||= BuildPart.find(@build_part_id)
  end

  def perform
    # Normally we would promote a ref after all the parts succeed, but in the case of maven
    # projects each individual part corresponds to a distinct promotable project. We want
    # to promote this even if another part fails since there are a lot of projects and
    # one is usually broken!
    if build.project.main_build? && build_part.successful?
      if promotion_ref = build.deployable_branch(build_part.paths.first)
        GithubRequest.post(
            URI("#{build.repository.base_api_url}/git/refs"),
            :ref => "refs/heads/deployable-#{promotion_ref}",
            :sha => build.ref
        )
        GithubRequest.post(
            URI("#{build.repository.base_api_url}/git/refs"),
            :ref => "refs/heads/ci-#{promotion_ref}-master/latest",
            :sha => build.ref
        )
      end
    end

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
