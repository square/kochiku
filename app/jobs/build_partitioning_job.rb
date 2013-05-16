require 'job_base'
require 'git_repo'
require 'github_commit_status'
require 'partitioner'

class BuildPartitioningJob < JobBase
  extend Resque::Plugins::Retry
  @queue = :partition

  @retry_limit = 5
  @retry_exceptions = {GitRepo::RefNotFoundError => [60, 60, 60, 120, 180]}

  def initialize(build_id)
    @build = Build.find(build_id)
  end

  def perform
    GitRepo.inside_copy(@build.repository, @build.ref, @build.branch) do
      @build.partition(Partitioner.new.partitions(@build))
      GithubCommitStatus.new(@build).update_commit_status!
    end
  end

  def on_exception(e)
    @build.update_attributes!(:state => :errored)
    super
  end
end
