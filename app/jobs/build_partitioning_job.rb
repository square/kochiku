require 'job_base'
require 'git_repo'
require 'partitioner'

class BuildPartitioningJob < JobBase
  extend Resque::Plugins::Retry
  @queue = :partition

  @retry_limit = 5
  @retry_exceptions = {GitRepo::RefNotFoundError => [60, 60, 60, 180, 360]}

  def initialize(build_id)
    @build = Build.find(build_id)
  end

  def perform
    @build.partition(Partitioner.new.partitions(@build))
    @build.update_commit_status!
  end

  def on_exception(e)
    if self.class.retry_exception?(e) && !self.class.retry_limit_reached?
      @build.update_attributes!(:state => :waiting_for_sync)
    else
      @build.update_attributes!(
          :state => :errored,
          :error_details => { :message => e.to_s, :backtrace => e.backtrace.join("\n") }
      )
    end
    super
  end
end
