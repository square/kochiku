class BuildPartResultObserver < ActiveRecord::Observer
  def after_save(record)
    BuildStateUpdateJob.enqueue(record.build_part.build_id)
  end
end
