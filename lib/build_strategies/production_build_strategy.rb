class BuildStrategy
  class << self
    # The primary function of promote_build is to push a new tag or update a branch
    #
    # A feature of promote build is that it will not cause the promotion ref to move
    # backwards. For instance, if build 1 finishes after build 2, we don't cause the promotion ref to move
    # backwards by overwriting promotion_ref with build 1
    def promote_build(build_ref, repository)
      unless included_in_promotion_ref?(build_ref)
        repository.promotion_refs.each do |promotion_ref|
          return if promotion_ref.strip.blank?
          if repository.use_branches_on_green
            Cocaine::CommandLine.new("git push", "origin :build_ref:refs/heads/#{promotion_ref} -f", :build_ref => build_ref).run
          else
            Cocaine::CommandLine.new("git push", "origin :build_ref:refs/tags/#{promotion_ref} -f", :build_ref => build_ref).run
          end
        end
      end
    end

    def merge_ref(build)
      email = 'github@squareup.com'
      begin
        merger = GitAutomerge.new
        log = merger.automerge(build)
        AutoMergeMailer.merge_successful(email, log, build).deliver
      rescue UnableToMergeError => ex
        AutoMergeMailer.merge_failed(email, ex.message, build).deliver
      end
    end

  private

    def included_in_promotion_ref?(build_ref)
      cherry_cmd = Cocaine::CommandLine.new("git cherry", "origin/#{promotion_ref} :build_ref", :build_ref => build_ref)
      cherry_cmd.run.lines.count == 0
    end
  end
end
