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

    remote = build.repository.remote_server
    remote.promote_branch!("deployable-#{@promotion_ref}", build.ref)
    remote.promote_branch!("ci-#{@promotion_ref}-master/latest", build.ref)
  end
end
