class BuildPartitioningJob < JobBase
  @queue = :partition

  def initialize(build_id)
    @build = Build.find(build_id)
  end

  def perform
    GitRepo.inside_copy("web-cache", @build.ref) do
      @build.partition(Partitioner.new.partitions)
    end
  end

  def on_exception(e)
    @build.update_attributes!(:state => :errored)
    super
  end
end
