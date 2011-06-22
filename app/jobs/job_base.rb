class JobBase
  def self.enqueue_on(build_queue, *args)
    Resque::Job.create(build_queue, self, *args)
    Resque::Plugin.after_enqueue_hooks(self).each do |hook|
      klass.send(hook, *args)
    end
  end

  def self.perform(*args)
    job = new(*args)
    job.perform
  rescue => e
    if job
      job.on_exception(e)
    else
      raise e
    end
  end

  def on_exception(e)
    raise e
  end
end
