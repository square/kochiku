require 'open3'

class GitMergeExecutor
  class UnableToMergeError < StandardError; end

  # Public: Merges the branch associated with a build into the master branch
  # and pushes the result to remote git repo. If the merge is unsuccessful for
  # any reason the merge is aborted and an exception is raised.
  #
  # build - ActiveRecord object for a build
  #
  def merge(build)
    Rails.logger.info("Trying to merge branch: #{build.branch} to master after build id: #{build.id}")

    checkout_log, status = Open3.capture2e("git checkout master && git pull")
    raise_and_log("Was unable checkout and pull master:\n\n#{checkout_log}") if status.exitstatus != 0

    commit_message = "Kochiku merge of branch #{build.branch} for build id: #{build.id} ref: #{build.ref}"
    merge_log, status = Open3.capture2e(merge_env, "git merge --no-ff -m '#{commit_message}' #{build.ref}")
    abort_merge_and_raise("git merge --abort",
      "Was unable to merge your branch:\n\n#{merge_log}") unless status.success?

    push_log, status = Open3.capture2e("git push origin master")
    rebase_log, second_push_log = recover_failed_push unless status.success?

    [checkout_log, merge_log, push_log, rebase_log, second_push_log].join("\n")
  end

  private

  def merge_env
    author_name  = "kochiku-merger"
    author_email = "noreply+kochiku-merger@#{Settings.domain_name}"
    {"GIT_AUTHOR_NAME" => author_name, "GIT_COMMITTER_NAME" => author_name,
     "GIT_AUTHOR_EMAIL" => author_email, "GIT_COMMITTER_EMAIL" => author_email}
  end

  def recover_failed_push
    rebase_log, status = Open3.capture2e("git pull --rebase")
    # Someone else pushed and we are conflicted, abort rebase and remove merges
    abort_merge_and_raise("git rebase --abort; git reset --hard origin/master",
                          "Was unable to merge your branch:\n\n#{rebase_log}") unless status.success?

    # Try to push once more if it fails remove merges
    second_push_log, status = Open3.capture2e("git push origin master")
    abort_merge_and_raise("git reset --hard origin/master",
                          "Was unable to push your branch:\n\n#{second_push_log}") unless status.success?

    [rebase_log, second_push_log]
  end

  def raise_and_log(error)
    Rails.logger.error(error)
    raise UnableToMergeError, "Was unable checkout and pull master:\n\n#{error}"
  end

  # Merge failed, cleanup and abort
  def abort_merge_and_raise(reset_command, std_err_out)
    Open3.capture2e(reset_command)
    raise_and_log("Was unable to merge --no-ff:\n\n#{std_err_out}")
  end
end
