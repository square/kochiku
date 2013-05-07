class BuildAttemptObserver < ActiveRecord::Observer
  def after_save(record)
    if record.should_reattempt?
      record.build_part.rebuild!
    elsif record.state == :failed
      if record.elapsed_time.try(:>=, record.build_part.project.repository.timeout.minutes)
        BuildMailer.time_out_email(record).deliver
      end
    elsif record.state == :errored
      BuildMailer.error_email(record, record.error_txt).deliver
    end

    build = record.build_part.build_instance
    previous_state, new_state = build.update_state_from_parts!
    Rails.logger.info("Build #{build.id} state is now #{build.state}")
    unless previous_state == new_state
      BuildStateUpdateJob.enqueue(record.build_part.id)
    end
  end
end
