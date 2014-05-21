require 'open3'
require 'git_blame'
require 'git_merge_executor'

class BuildStrategy
  class << self
    # The primary function of promote_build is to update the branches specified
    # in on_green_update field of Repository.
    #
    # A feature of promote build is that it will not cause the promotion ref to move
    # backwards. For instance, if build 1 finishes after build 2, we don't cause the promotion ref to move
    # backwards by overwriting promotion_ref with build 1
    def promote_build(build_ref, repository)
      repository.promotion_refs.each do |promotion_ref|
        unless included_in_promotion_ref?(build_ref, promotion_ref)
          update_branch(promotion_ref, build_ref)
        end
      end
    end

    def add_note(build_ref, namespace, note)
      Cocaine::CommandLine.new("git fetch -f origin refs/notes/*:refs/notes/*").run
      Cocaine::CommandLine.new("git notes --ref=#{namespace} add -f -m '#{note}' #{build_ref}").run
      Cocaine::CommandLine.new("git push -f origin refs/notes/#{namespace}").run
    end

    def run_success_script(repository, build_ref, build_branch)
      GitRepo.inside_copy(repository, build_ref, build_branch) do |dir|
        output, status = Open3.capture2e(repository.on_success_script, :chdir => dir)
        output += "\nExited with status: #{status.exitstatus}"
        return output
      end
    end

    def merge_ref(build)
      begin
        emails = GitBlame.emails_in_branch(build)
        merger = GitMergeExecutor.new
        log = merger.merge(build)
        MergeMailer.merge_successful(build, emails, log).deliver
      rescue GitMergeExecutor::UnableToMergeError => ex
        MergeMailer.merge_failed(build, emails, ex.message).deliver
      end
    end

  private

    def included_in_promotion_ref?(build_ref, promotion_ref)
      return unless ref_exists?(promotion_ref)

      cherry_cmd = Cocaine::CommandLine.new("git cherry", "origin/#{promotion_ref} #{build_ref}")
      cherry_cmd.run.lines.count == 0
    end

    def ref_exists?(promotion_ref)
      show_ref = Cocaine::CommandLine.new("git show-ref", promotion_ref, :expected_outcodes => [0,1])
      show_ref.run.present?
    end

    def update_branch(branch_name, ref_to_promote)
      Cocaine::CommandLine.new("git push", "origin #{ref_to_promote}:refs/heads/#{branch_name}").run
    end

  end
end
