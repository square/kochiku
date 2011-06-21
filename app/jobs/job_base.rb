class JobBase
  def self.enqueue_in(build_queue, *args)
    Resque::Job.create(build_queue, self, *args)
    Resque::Plugin.after_enqueue_hooks(self).each do |hook|
      klass.send(hook, *args)
    end
  end

  def self.perform(*args)
    new(*args).perform
  end

end
