module ResqueQueueHelper
  module_function

  def remove_enqueued_build_attempt_jobs(queue, build_attempt_ids)
    queue = "queue:" + queue

    length = Resque.redis.llen(queue)
    length.times do |i|
      value = Resque.redis.lindex(queue, i)
      job_hash = JSON.parse(value)
      build_attempt_id = job_hash["args"].first
      if build_attempt_ids.include?(build_attempt_id)
        Resque.redis.lrem(queue, 0, value)
      end
    end
  end
end
