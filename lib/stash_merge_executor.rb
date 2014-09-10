require 'open3'
require 'git_merge_executor'

class StashMergeExecutor < GitMergeExecutor

  # Merges the branch associated with a build using the Stash REST api.
  # If an API error is raised, falls back on traditional method.
  def merge_and_push
    remote_server = @build.repository.remote_server
    if @build.project.name =~ /-pull_requests$/
      begin
        Rails.logger.info("Trying to merge branch #{@build.branch} to master after build id #{@build.id} using Stash REST api")
        merge_success = remote_server.merge(@build.branch)
        unless merge_success
          raise GitMergeFailedError
        end
        return "Successfully merged #{@build.branch}"
      rescue RemoteServer::StashAPIError
        Rails.logger.info("Error using StashAPI, falling back on old merge method")
      end
    end

    super
  end

  # Delete branch associated with a build using Stash REST api.
  # If method fails, falls back on traditional method.
  def delete_branch
    remote_server = @build.repository.remote_server
    begin
      Rails.logger.info("Trying to delete branch using Stash REST api")
      remote_server.delete_branch(@build.branch)
    rescue StashAPIError => e
      Rails.logger.warn("Deletion of branch #{@build.branch} failed")
      Rails.logger.warn(e.message)
      super
    end
  end
end
