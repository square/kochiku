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

  private

    def included_in_promotion_ref?(build_ref)
      cherry_cmd = Cocaine::CommandLine.new("git cherry", "origin/#{promotion_ref} :build_ref", :build_ref => build_ref)
      cherry_cmd.run.lines.count == 0
    end
  end
end
