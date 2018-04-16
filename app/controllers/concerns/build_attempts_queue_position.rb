module BuildAttemptsQueuePosition
  extend ActiveSupport::Concern

  def calculate_build_attempts_position(build_attempts, queue)
    @build_attempts_rank = {}
    jobs = Resque.redis.lrange("queue:#{queue}", 0, -1)
    return if jobs.blank?
    build_attempts&.each do |build_attempt|
      next unless build_attempt.state == 'runnable'
      id = build_attempt.id.to_s
      @build_attempts_rank[id] = jobs.index { |job| /"build_attempt_id\":#{id}/.match(job) }
    end
  end

  def calculate_build_parts_position(build)
    parts_by_queue = Hash.new([])
    build_attempts = build.build_attempts.includes(:build_part).where(state: 'running')
    build_attempts.each do |attempt|
      parts_by_queue[attempt.build_part.queue] += [attempt]
    end

    parts_by_queue.each do |queue, attempts|
      calculate_build_attempts_position(attempts, queue)
    end
  end
end
