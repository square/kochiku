class BuildStateUpdateJob < JobBase
  @queue = :high

  def initialize(build_id)
    @build_id = build_id
  end

  def perform
    build = Build.find(@build_id)
    unless build.finished?
      build.update_state_from_parts!

      if build.state == :succeeded && build.promotable?
        GitRepo.inside_copy("web-cache", build.sha) do
          `git remote add destination git@github.com:square/web.git`
          `git push -f destination #{build.sha}:refs/heads/#{build.promotion_ref}`
        end
      end
    end
  end
end
