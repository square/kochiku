class BuildAttemptObserver < ActiveRecord::Observer
  def after_save(record)
    if record.should_reattempt?
      record.build_part.rebuild!
    elsif record.state != :runnable && record.state != :running
      BuildStateUpdateJob.enqueue(record.build_part.build_id)
    end
  end
end
