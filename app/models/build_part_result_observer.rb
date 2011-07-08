class BuildPartResultObserver < ActiveRecord::Observer
  def after_save(record)
    if record.state != :runnable && record.state != :running
      BuildStateUpdateJob.enqueue(record.build_part.build_id)
    end
  end
end
