require 'open3'
require 'git_merge_executor'

class StashMergeExecutor < GitMergeExecutor

  # Merges the branch associated with a build using the Stash REST api.
  def merge_and_push
    remote_server = @build.repository.remote_server
    Rails.logger.info("Trying to merge branch #{@build.branch_record.name} after build id #{@build.id} using Stash REST api")
    branch_name = @build.branch_record.name
    head_commit = remote_server.head_commit(branch_name)
    merge_success = remote_server.merge(branch_name)
    unless merge_success
      Rails.logger.info("Merge of #{@build.branch_record.name} failed.")
      raise GitMergeFailedError
    end
    { ref: head_commit, log_output: "Successfully merged #{@build.branch_record.name}" }
  end

  # Delete branch associated with a build using Stash REST api.
  def delete_branch
    remote_server = @build.repository.remote_server
    begin
      Rails.logger.info("Trying to delete branch using Stash REST api")
      remote_server.delete_branch(@build.branch_record.name)
    rescue RemoteServer::StashAPIError => e
      Rails.logger.warn("Deletion of branch #{@build.branch_record.name} failed")
      Rails.logger.warn(e.message)
    end
  end
end
