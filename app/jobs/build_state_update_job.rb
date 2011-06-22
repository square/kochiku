class BuildStateUpdateJob < JobBase
  def initialize(build_id)
    @build_id = build_id
  end

  def perform
    build = Build.find(@build_id)
    build.update_state_from_parts!
  end
end
