require 'open3'

class GitMergeExecutor
  class GitFetchFailedError < StandardError; end
  class GitMergeFailedError < StandardError; end
  class GitPushFailedError < StandardError; end

  def initialize(build)
    if build.branch_record.convergence?
      raise "attempted to merge #{build.branch_record.name} which is a convergence branch and is ineligible for merge by Kochiku"
    end
    @build = build
  end

  # Public: Merges the branch associated with a build into the master branch
  # and pushes the result to remote git repo. If the merge is unsuccessful for
  # any reason the merge is aborted and an exception is raised.
  #
  # build - ActiveRecord object for a build
  #
  def merge_and_push
    Rails.logger.info("Trying to merge branch: #{@build.branch_record.name} to master after build id: #{@build.id}")

    begin
      git_fetch_and_reset

      ref, merge_log = merge_to_master

      push_log = push_to_remote
    rescue GitFetchFailedError, GitPushFailedError
      tries = (tries || 0) + 1
      if tries < 3
        sleep(10 * tries)
        retry
      else
        raise
      end
    end

    { ref: ref, log_output: [merge_log, push_log].join("\n") }
  end

  def delete_branch
    begin
      git_fetch_and_reset

      delete_log, status = Open3.capture2e("git push --porcelain --delete origin #{@build.branch_record.name}")
      unless status.success?
        Rails.logger.warn("Deletion of branch #{@build.branch_record.name} failed")
        Rails.logger.warn(delete_log)
      end
    rescue GitFetchFailedError
      Rails.logger.warn("Deletion of branch #{@build.branch_record.name} failed")
    end
  end

  private

  def git_fetch_and_reset
    checkout_log, status = Open3.capture2e("git fetch && git checkout master && git reset --hard origin/master")
    unless status.success?
      raise_and_log(GitFetchFailedError, "Error occurred while reseting to origin/master:", checkout_log)
    end
  end

  def merge_to_master
    commit_message = "Kochiku merge of branch #{@build.branch_record.name} for build id: #{@build.id} ref: #{@build.ref}"
    merge_log, status = Open3.capture2e(merge_env, "git merge --no-ff -m '#{commit_message}' #{@build.ref}")

    unless status.success?
      Open3.capture2e("git merge --abort")
      raise_and_log(GitMergeFailedError, "Was unable to merge your branch:", merge_log)
    end

    newest_ref, _status = Open3.capture2e("git rev-parse master")
    [newest_ref.chomp, merge_log]
  end

  def push_to_remote
    push_log, status = Open3.capture2e("git push --porcelain origin master")

    unless status.success?
      raise_and_log(GitPushFailedError, "git push of branch #{@build.branch_record.name} failed:", push_log)
    end

    push_log
  end

  def raise_and_log(error_class, error_info, command_output)
    message = "#{error_info}\n\n#{command_output}"
    Rails.logger.error(message)
    raise(error_class, message)
  end

  def merge_env
    author_name  = "kochiku-merger"
    author_email = "noreply+kochiku-merger@#{Settings.domain_name}"
    {"GIT_AUTHOR_NAME" => author_name, "GIT_COMMITTER_NAME" => author_name,
     "GIT_AUTHOR_EMAIL" => author_email, "GIT_COMMITTER_EMAIL" => author_email}
  end
end
