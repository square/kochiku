require 'job_base'
require 'github_request'

# this job pushes a ref to a deployable branch. it is enqueued when a
# build_part's state changes.
class BranchUpdateJob < JobBase
  @queue = :high

  def initialize(build_id, promotion_ref)
    @build_id = build_id
    @promotion_ref = promotion_ref
  end

  def perform
    build = Build.find(@build_id)
    GithubRequest.post(
      URI("#{build.repository.base_api_url}/git/refs"),
      :ref => "refs/heads/deployable-#{@promotion_ref}",
      :sha => build.ref
    )

    GithubRequest.post(
      URI("#{build.repository.base_api_url}/git/refs"),
      :ref => "refs/heads/ci-#{@promotion_ref}-master/latest",
      :sha => build.ref
    )
  end
end
