class BuildStateUpdateJob < JobBase
  @queue = :high

  def initialize(build_id)
    @build_id = build_id
  end

  def perform
    build = Build.find(@build_id)
    unless build.succeeded?
      build.update_state_from_parts!

      if build.state == :succeeded && build.promotable?
        GitRepo.inside_copy("web-cache", build.sha) do
          `git remote add destination git@github.com:square/web.git`
          system(PROMOTION_COMMAND(build))
        end
      end
    end
  end
end
