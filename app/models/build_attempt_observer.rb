class BuildAttemptObserver < ActiveRecord::Observer
  def after_save(record)
    if record.should_reattempt?
      record.build_part.rebuild!
    elsif record.state == :failed
      if record.elapsed_time.try(:>=, record.build_part.project.repository.timeout.minutes)
        BuildMailer.time_out_email(record).deliver
      end
    elsif record.state == :errored
      first_line_of_error = nil
      if error_artifact = record.build_artifacts.select{|a| a.log_file.try(:to_s) =~ /error\.txt/}.try(:first)
        first_line_of_error = File.open(error_artifact.log_file.path).first
      end
      BuildMailer.error_email(record, first_line_of_error).deliver
    end
    BuildStateUpdateJob.enqueue(record.build_part.build_id)
  end
end
