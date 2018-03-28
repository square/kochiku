class TimeoutStuckBuildsJob < JobBase
  @queue = :high

  def self.perform
    clean_lost_builds
    clean_runnable_not_queued
  end

  def self.clean_runnable_not_queued
    # check for builds in runnable that are no longer in the queue
    missing = []
    BuildAttempt.select("build_attempts.id", " build_parts.queue as queue").joins(:build_part)
                .where("build_attempts.state = 'runnable' AND build_attempts.created_at < ? AND build_attempts.created_at > ?", 5.minutes.ago, 1.day.ago)
                .group_by(&:queue)
                .each do |queue, attempts|
                  current_queue = Resque.redis.lrange("queue:#{queue}", 0, -1).to_s
                  missing += attempts.reject { |attempt| current_queue.match(/build_attempt_id\\*\"\:#{attempt.id}[^0-9]/) }
                end

    missing.select! { |build_attempt_partial| BuildAttempt.find(build_attempt_partial.id).state == 'runnable' }
    missing.each { |build_attempt_partial| BuildAttempt.find(build_attempt_partial.id).finish!('errored') }
  end

  def self.clean_lost_builds
    # check for builds that have hit their assume_lost_after
    Repository.where("assume_lost_after IS NOT NULL").find_each do |repo|
      repo.build_attempts.where("build_attempts.state = 'running' AND build_attempts.started_at < ?", repo.assume_lost_after.minutes.ago).each do |build_attempt|
        build_attempt.finish!('errored')
      end
    end
  end
end
