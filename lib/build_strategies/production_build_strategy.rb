require 'open3'
class BuildStrategy
  class << self
    # The primary function of promote_build is to push a new tag or update a branch
    #
    # A feature of promote build is that it will not cause the promotion ref to move
    # backwards. For instance, if build 1 finishes after build 2, we don't cause the promotion ref to move
    # backwards by overwriting promotion_ref with build 1
    def promote_build(build_ref, repository)
      repository.promotion_refs.each do |promotion_ref|
        unless included_in_promotion_ref?(repository, build_ref, promotion_ref)
          if repository.use_branches_on_green
            command = "git push", "origin #{build_ref}:refs/heads/#{promotion_ref} -f"
            output  = Cocaine::CommandLine.new(command).run
          else
            command = "git push", "origin #{build_ref}:refs/tags/#{promotion_ref} -f"
            output  = Cocaine::CommandLine.new(command).run
          end
        end
      end
    rescue Cocaine::ExitStatusError => e
      # Cocaine doesn't log command line output in its exceptions, so we store it off manually
      # What's more, Exception#message= doesn't exist, so we can't stuff the output in there
      Rails.logger.error [command, e.message, output, *e.backtrace].join("\n")
      raise
    end

    def run_success_script(build_ref, repository)
      GitRepo.inside_copy(repository, build_ref) do |dir|
        output, status = Open3.capture2e(repository.on_success_script, :chdir => dir)
        output += "\nExited with status: #{status.exitstatus}"
        return output
      end
    end

    def merge_ref(build)
      begin
        emails = GitBlame.emails_since_last_green(@build)
        merger = GitAutomerge.new
        log = merger.automerge(build)
        AutoMergeMailer.merge_successful(build, emails, log).deliver
      rescue GitAutomerge::UnableToMergeError => ex
        AutoMergeMailer.merge_failed(build, emails, ex.message).deliver
      end
    end

  private

    def included_in_promotion_ref?(repository, build_ref, promotion_ref)
      target_to_check = if repository.use_branches_on_green
        "origin/#{promotion_ref}"
      else
        promotion_ref
      end
      cherry_cmd = Cocaine::CommandLine.new("git cherry", "#{target_to_check} #{build_ref}")
      cherry_cmd.run.lines.count == 0
    end
  end
end
