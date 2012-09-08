class JobBase
  def initialize
    # Ensure the log is flushed, even if this job exits quickly or never exceeds the log buffer.
    Rails.logger.auto_flushing = true
  end

  class << self
    def enqueue(*args)
      Resque.enqueue(self, *args)
    end

    def enqueue_on(build_queue, *args)
      Resque::Job.create(build_queue, self, *args)
      Resque::Plugin.after_enqueue_hooks(self).each do |hook|
        klass.send(hook, *args)
      end
    end

    def perform(*args)
      job = new(*args)
      job.perform
    rescue => e
      if job
        job.on_exception(e)
      else
        raise e
      end
    end
  end

  def on_exception(e)
    raise e
  end
end
