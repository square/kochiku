class BuildStateUpdateJob < JobBase
  @queue = :high

  def initialize(build_id)
    @build_id = build_id
  end

  def perform
    build = Build.find(@build_id)
    build.update_state_from_parts!

    if build.promotable?
      GitRepo.inside_bare("web-bare") do
        build.promote!
      end
    end
  end
end
