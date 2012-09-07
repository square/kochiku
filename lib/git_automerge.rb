class UnableToMergeError < StandardError; end

class GitAutomerge
  def automerge(build, build_url)
    Rails.logger.info("Trying auto_merge to master for #{build_url}")

    checkout_log, status = Open3.capture2e("git checkout master && git pull")
    raise_and_log("Was unable checkout and pull master:\n\n#{checkout_log}") if status.exitstatus != 0

    merge_log, status = Open3.capture2e(
      {"GIT_AUTHOR_NAME" => "kochiku-automerger",
       "GIT_AUTHOR_EMAIL" => "noreply+kochiku-automerger@squareup.com"},
      "git merge --no-ff -m 'Automerge branch #{build.branch} for kochiku build: #{build_url}' #{build.ref}"
    )
    abort_merge_and_raise("git merge --abort",
      "Was unable to merge your branch:\n\n#{merge_log}") if status.exitstatus != 0

    push_log, status = Open3.capture2e("git push origin master")
    if status.exitstatus != 0
      rebase_log, second_push_log = recover_failed_push
    end

    [checkout_log, merge_log, push_log, rebase_log, second_push_log].join("\n")
  end

  private

  def recover_failed_push
    rebase_log, rebase_status = Open3.capture2e("git pull --rebase")
    # Someone else pushed and we are conflicted, abort rebase and remove merges
    abort_merge_and_raise("git rebase --abort; git reset --hard origin/master",
                          "Was unable to merge your branch:\n\n#{rebase_log}") if rebase_status.exitstatus != 0

    # Try to push once more if it fails remove merges
    second_push_log, status = Open3.capture2e("git push origin master")
    abort_merge_and_raise("git reset --hard origin/master",
                          "Was unable to push your branch:\n\n#{second_push_log}") if status.exitstatus != 0

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
