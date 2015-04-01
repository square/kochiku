require 'git_blame'

class BuildStrategy
  class << self
    # The primary function of promote_build is to update the branches specified
    # in on_green_update field of Repository.
    #
    # A feature of promote_build is that it will not cause the promotion ref to
    # move backwards. For instance, if build 1 finishes after build 2, we don't
    # cause the promotion ref to move backwards by overwriting promotion_ref
    # with build 1
    #
    # promote_build does use a force push in order to overwrite experimental
    # branches that may have been manually placed on the promotion ref by a
    # developer for testing.
    def promote_build(build)
      GitRepo.inside_repo(build.repository) do
        build.repository.promotion_refs.each do |promotion_ref|
          unless GitRepo.included_in_promotion_ref?(build.ref, promotion_ref)
            update_branch(promotion_ref, build.ref)
          end
        end
      end
    end

    def run_success_script(build)
      GitRepo.inside_copy(build.repository, build.ref) do
        command = Cocaine::CommandLine.new(build.on_success_script, "", :expected_outcodes => 0..255)
        output = command.run
        output += "\nExited with status: #{command.exit_status}"
        script_log = FilelessIO.new(output)
        script_log.original_filename = "on_success_script.log"
        build.on_success_script_log_file = script_log
        build.save!
      end
    end

    def merge_ref(build)
      GitRepo.inside_repo(build.repository) do
        begin
          emails = GitBlame.emails_in_branch(build)
          merger = build.repository.remote_server.merge_executor.new(build)
          command_output = merger.merge_and_push
          if build.repository.send_merge_successful_email?
            MergeMailer.merge_successful(build, emails, command_output).deliver
          end
          merger.delete_branch
        rescue GitMergeExecutor::GitMergeFailedError => ex
          MergeMailer.merge_failed(build, emails, ex.message).deliver
        end
      end
    end

    def update_branch(branch_name, ref_to_promote)
      Cocaine::CommandLine.new("git push", "--force origin #{ref_to_promote}:refs/heads/#{branch_name}").run
    end
  end
end
