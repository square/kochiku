require 'open3'

class GitAutomerge
  class UnableToMergeError < StandardError; end

  def automerge(build)
    Rails.logger.info("Trying auto_merge to master for build id: #{build.id}  branch: #{build.branch}")

    checkout_log, status = Open3.capture2e("git checkout master && git pull")
    raise_and_log("Was unable checkout and pull master:\n\n#{checkout_log}") if status.exitstatus != 0

    commit_message = "Automerge branch #{build.branch} for kochiku build id: #{build.id} ref: #{build.ref}"
    merge_log, status = Open3.capture2e(merge_env, "git merge --no-ff -m '#{commit_message}' #{build.ref}")
    abort_merge_and_raise("git merge --abort",
      "Was unable to merge your branch:\n\n#{merge_log}") unless status.success?

    push_log, status = Open3.capture2e("git push origin master")
    rebase_log, second_push_log = recover_failed_push unless status.success?

    [checkout_log, merge_log, push_log, rebase_log, second_push_log].join("\n")
  end

  private

  def merge_env
    author_name  = "kochiku-automerger"
    author_email = "noreply+kochiku-automerger@#{Settings.domain_name}"
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
