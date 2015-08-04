require 'open3'
require 'git_merge_executor'

class StashMergeExecutor < GitMergeExecutor

  # Merges the branch associated with a build using the Stash REST api.
  def merge_and_push
    remote_server = @build.repository.remote_server
    if @build.project.name =~ /-pull_requests$/
      Rails.logger.info("Trying to merge branch #{@build.branch} after build id #{@build.id} using Stash REST api")
      merge_success = remote_server.merge(@build.branch)
      unless merge_success
        Rails.logger.info("Merge of #{@build.branch} failed.")
        raise GitMergeFailedError
      end
      return "Successfully merged #{@build.branch}"
    end
  end

  # Delete branch associated with a build using Stash REST api.
  def delete_branch
    remote_server = @build.repository.remote_server
    begin
      Rails.logger.info("Trying to delete branch using Stash REST api")
      remote_server.delete_branch(@build.branch)
    rescue RemoteServer::StashAPIError => e
      Rails.logger.warn("Deletion of branch #{@build.branch} failed")
      Rails.logger.warn(e.message)
    end
  end
end
