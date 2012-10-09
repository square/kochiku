class BuildPartitioningJob < JobBase
  @queue = :partition

  def initialize(build_id)
    @build = Build.find(build_id)
  end

  def perform
    GitRepo.inside_copy(@build.repository.repo_cache_name, @build.ref) do
      @build.partition(Partitioner.new.partitions)
      GithubCommitStatus.new(@build).update_commit_status!
    end
  end

  def on_exception(e)
    @build.update_attributes!(:state => :errored)
    super
  end
end
