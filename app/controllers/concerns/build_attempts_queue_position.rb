module BuildAttemptsQueuePosition
  extend ActiveSupport::Concern

  # keep_rank is only true if we are calling calculate_build_attempts_position multiple times on the
  # same build because that build has multiple queues
  def calculate_build_attempts_position(build_attempts, queue, keep_rank: false)
    @build_attempts_rank = {} unless keep_rank
    jobs = Resque.redis.lrange("queue:#{queue}", 0, -1)
    return if jobs.blank?
    build_attempts&.each do |build_attempt|
      next unless build_attempt.state == 'runnable'
      id = build_attempt.id.to_s
      @build_attempts_rank[id] = jobs.index { |job| /"build_attempt_id\":#{id}/.match(job) }
    end
  end

  def calculate_build_parts_position(build)
    @build_attempts_rank = {}
    parts_by_queue = Hash.new([])
    build_attempts = build.build_attempts.includes(:build_part).where(state: 'runnable')
    build_attempts.each do |attempt|
      parts_by_queue[attempt.build_part.queue] += [attempt]
    end

    parts_by_queue.each do |queue, attempts|
      calculate_build_attempts_position(attempts, queue, keep_rank: true)
    end
  end
end
