class BuildAttemptObserver < ActiveRecord::Observer
  TIMEOUT_THRESHOLD = 40.minutes

  def after_save(record)
    if record.should_reattempt?
      record.build_part.rebuild!
    elsif record.state == :failed && record.elapsed_time.try(:>=, TIMEOUT_THRESHOLD)
      BuildPartTimeOutMailer.time_out_email(record.build_part)
    end
    BuildStateUpdateJob.enqueue(record.build_part.build_id)
  end
end
