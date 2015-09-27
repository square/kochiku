# AutosizeWorkersJob adjusts the number of workers running based on utilization
# thresholds.
class AutosizeWorkersJob < JobBase
  @queue = :high

  def self.perform
    worker_thresholds = Settings.worker_thresholds
    return unless worker_thresholds.present?
    stat_list = REDIS.lrange(MonitorWorkersJob::REDIS_STATS_KEY, 0, -1)
    return if stat_list.length < worker_thresholds[:number_of_samples]
    current_workers = Resque.info[:workers]
    Rails.logger.info "[AutosizeWorkersJob] current worker count: #{current_workers}"
    workers_to_shutdown = [worker_thresholds[:instance_chunk_size], current_workers-worker_thresholds[:minimum_total_workers]].min
    Rails.logger.info "[AutosizeWorkersJob] workers_to_shutdown => #{workers_to_shutdown}"
    workers_to_spinup = [worker_thresholds[:instance_chunk_size], worker_thresholds[:maximum_total_workers]-current_workers].min
    Rails.logger.info "[AutosizeWorkersJob] workers_to_spinup => #{workers_to_spinup}"
    most_recent_time = nil
    worker_fluctuation_tolerance = worker_thresholds[:worker_fluctuation_tolerance]
    stat_list.each do |json_stat|
      stat = JSON.parse(json_stat).symbolize_keys

      if (current_workers - stat[:workers]).abs > worker_fluctuation_tolerance # make sure the number of workers is stable
        Rails.logger.info "[AutosizeWorkersJob] Number of workers is not stable."
        return
      end
      free_workers = stat[:workers] - stat[:working]
      workers_to_shutdown = 0 if free_workers < worker_thresholds[:idle_excess_count]
      workers_to_spinup = 0 if free_workers > worker_thresholds[:idle_insufficient_count]
      if workers_to_shutdown == 0 && workers_to_spinup == 0
        Rails.logger.info "[AutosizeWorkersJob] No increase or decrease of workers needed at this time."
        return
      end
      # Make sure our job is running close to every 10 seconds.
      if most_recent_time && (( most_recent_time - stat[:when] > 12) || (most_recent_time - stat[:when] < 8))
        Rails.logger.info "Inconsistent worker performance.  Time between datapoints: #{most_recent_time - stat[:when]}"
      end
      most_recent_time = stat[:when]
    end

    # reset stats on the server so we only resize once.
    REDIS.del(MonitorWorkersJob::REDIS_STATS_KEY)
    # adjust pool size up or down as needed.
    adjust_worker_count(workers_to_spinup - workers_to_shutdown)
  end

  # positve count for spin up, negative count for shutdown
  def self.adjust_worker_count(count)
    if count < 0
      # Enqueue N ShutdownInstanceJobs. ShutdownInstanceJob is defined inside kochiku-worker.
      Rails.logger.info "[AutosizeWorkersJob] Shutting down #{count.abs} idle workers"
      count.abs.times { Resque.enqueue_to(Settings.worker_thresholds[:autosize_queue], 'ShutdownInstanceJob') }
    else
      # Call script responsible for launching N workers
      Rails.logger.info "[AutosizeWorkersJob] Spinning up #{count} workers via #{Settings.worker_thresholds[:spin_up_script]}"
      Cocaine::CommandLine.new(Settings.worker_thresholds[:spin_up_script], count.to_s).run
    end
  end
end
