class BuildStateUpdateJob < JobBase
  @queue = :high

  def initialize(build_id)
    @build_id = build_id
  end

  def perform
    build = Build.find(@build_id)
    unless build.succeeded?
      build.update_state_from_parts!

      if build.promotable?
        GitRepo.inside_repo("web-cache") do
          build.promote!
        end
      end
    end
  end
end
