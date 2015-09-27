# This job is run every 10 seconds on master.  Record the current Resque statistics
class MonitorWorkersJob < JobBase
  REDIS_STATS_KEY = "WORKER_STAT_LIST"
  @queue = :high

  def self.perform
    return unless Settings.worker_thresholds

    REDIS.ltrim(MonitorWorkersJob::REDIS_STATS_KEY, 0, Settings.worker_thresholds[:number_of_samples]-2)
    stats = Resque.info
    # add timestamp to stats so we can make sure the sampling is stable.
    stats[:when] = Time.now.to_i
    REDIS.lpush(MonitorWorkersJob::REDIS_STATS_KEY, stats.to_json)
  end
end
