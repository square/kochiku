class BuildPartResultObserver < ActiveRecord::Observer
  def after_create(record)
    BuildStateUpdateJob.enqueue(record.build_part.build_id)
  end
end
