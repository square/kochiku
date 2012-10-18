class BuildAttemptObserver < ActiveRecord::Observer
  TIMEOUT_THRESHOLD = 40.minutes

  def after_save(record)
    if record.should_reattempt?
      record.build_part.rebuild!
    elsif record.state == :failed
      if record.elapsed_time.try(:>=, TIMEOUT_THRESHOLD)
        BuildPartMailer.time_out_email(record.build_part).deliver
      elsif record.build_part.project.branch == "master" && record.build_part.build_instance.previous_successful_build
        BuildPartMailer.build_break_email(GitBlame.emails_of_build_breakers(record.build_part.build_instance), record).deliver
      end
    end
    BuildStateUpdateJob.enqueue(record.build_part.build_id)
  end
end
