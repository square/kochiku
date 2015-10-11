require 'job_base'
require 'git_repo'
require 'partitioner'

class BuildPartitioningJob < JobBase
  extend Resque::Plugins::Retry
  @queue = :partition

  @retry_limit = 5
  @retry_exceptions = {GitRepo::RefNotFoundError => [60, 60, 60, 180, 360],
                       Cocaine::ExitStatusError => [30, 60, 60, 60, 60] }

  def initialize(build_id)
    @build = Build.find(build_id)
  end

  def perform
    if @build.test_command.blank?
      error_message = "No test_command specified in kochiku.yml."
      @build.update!(:error_details => { :message => error_message, :backtrace =>nil }, :state => :errored)
      @build.update_commit_status!
      return
    end
    @build.partition(Partitioner.for_build(@build).partitions)
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
      @build.update_commit_status!
    end
    super
  end
end
