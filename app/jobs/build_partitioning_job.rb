class BuildPartitioningJob < JobBase
  @queue = :partition

  def initialize(build_id)
    @build_id = build_id
  end

  def perform
    #partition!
  end
end
