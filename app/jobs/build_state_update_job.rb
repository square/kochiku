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
          Cocaine::CommandLine.new("git remote add destination git@git.squareup.com:square/web.git", :expected_outcodes => [0, 128], :swallow_stderr => true).run
          build.promote!
        end
      end
    end
  end
end
