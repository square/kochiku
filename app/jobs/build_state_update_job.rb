class BuildStateUpdateJob < JobBase
  @queue = :high

  def initialize(build_id)
    @build_id = build_id
  end

  def perform
    build = Build.find(@build_id)
    build.update_state_from_parts!

    if build.promotable?
      GitRepo.inside_repo("web-cache") do
        build.promote!
      end
    elsif build.auto_mergable?
      GitRepo.inside_repo("web-cache") do
        build.auto_merge!
      end
    end
  end
end
