module BuildAttemptsQueuePosition
  extend ActiveSupport::Concern

  def calculate_build_attempts_position(build_attempts)
    @build_attempts_rank = {}
    build_attempts.includes(:build_part).each do |build_attempt|
      queue = build_attempt.build_part.queue
      cur_queue_size = Resque.size(queue)
      id = build_attempt.id.to_s
      jobs = Resque.peek(queue, 0, cur_queue_size + 1)
      if jobs.present? && build_attempt.state == 'runnable'
        @build_attempts_rank[id] = jobs.index { |job| job['args'].first['build_attempt_id'] == build_attempt.id }
      end
    end
  end
end
