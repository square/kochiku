require 'open3'

class BuildStrategy
  class << self
    # The primary function of promote_build is to push a new tag or update a branch
    #
    # A feature of promote build is that it will not cause the promotion ref to move
    # backwards. For instance, if build 1 finishes after build 2, we don't cause the promotion ref to move
    # backwards by overwriting promotion_ref with build 1
    def promote_build(build_ref)
      unless included_in_promotion_ref?(build_ref)
        Cocaine::CommandLine.new("git push", "origin :build_ref:refs/heads/#{promotion_ref} -f", :build_ref => build_ref).run
      end
    end

    def promotion_ref
      "ci-master-distributed-latest"
    end

    def merge_ref(build)
      email = 'github@squareup.com'
      begin
        log = try_to_automerge(build.ref)
        merge_ref, status = Open3.capture2e("git rev-parse HEAD")
        AutoMergeMailer.merge_successful(email, log, merge_ref, build).deliver
      rescue UnableToMergeError => ex
        AutoMergeMailer.merge_failed(email, ex.message, build).deliver
      end
    end

  private

    def included_in_promotion_ref?(build_ref)
      cherry_cmd = Cocaine::CommandLine.new("git cherry", "origin/#{promotion_ref} :build_ref", :build_ref => build_ref)
      cherry_cmd.run.lines.count == 0
    end

    class UnableToMergeError < StandardError; end

    # This behavior really belongs in a different object
    def try_to_automerge(ref)
      checkout_log, status = Open3.capture2e("git checkout master && git pull")
      raise_and_log("Was unable checkout and pull master:\n\n#{checkout_log}") if status.exitstatus != 0

      merge_log, status = Open3.capture2e("git merge --no-ff #{ref}")
      abort_merge_and_raise("git merge --abort", "Was unable to merge your branch:\n\n#{merge_log}") if status.exitstatus != 0

      push_log, status = Open3.capture2e("git push origin master")
      if status.exitstatus != 0
        rebase_log, rebase_status = Open3.capture2e("git pull --rebase")
        # Someone else pushed and we are conflicted, abort rebase and remove merges
        abort_merge_and_raise("git rebase --abort; git reset --hard origin/master", "Was unable to merge your branch:\n\n#{rebase_log}") if rebase_status.exitstatus != 0
        # Try to push once more if it fails remove merges
        second_push_log, status = Open3.capture2e("git push origin master")
        abort_merge_and_raise("git reset --hard origin/master", "Was unable to push your branch:\n\n#{second_push_log}") if status.exitstatus != 0
      end

      [checkout_log, merge_log, push_log, rebase_log, second_push_log].join("\n")
    end

    def raise_and_log(error)
      Rails.logger.error(error)
      raise UnableToMergeError("Was unable checkout and pull master:\n\n#{std_err_out}")
    end

    # Merge failed, cleanup and abort
    def abort_merge_and_raise(reset_command, std_err_out)
      Open3.capture2e(reset_command)
      raise_and_log("Was unable to merge --no-ff:\n\n#{std_err_out}")
    end
  end
end
