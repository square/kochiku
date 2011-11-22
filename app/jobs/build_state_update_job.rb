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
    end

    # this needs to run on the master host
    File.write(Rails.root.join("public", "log_files", build.project.name, "build_#{build.id}", "build-state")) do |f|
      f << build.state
    end
  end
end
