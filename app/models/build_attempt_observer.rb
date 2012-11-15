class BuildAttemptObserver < ActiveRecord::Observer
  def after_save(record)
    if record.should_reattempt?
      record.build_part.rebuild!
    elsif record.state == :failed
      if record.elapsed_time.try(:>=, record.build_part.project.repository.timeout.minutes)
        BuildMailer.time_out_email(record).deliver
      end
    elsif record.state == :errored
      BuildMailer.error_email(record).deliver
    end
    BuildStateUpdateJob.enqueue(record.build_part.build_id)
  end
end
