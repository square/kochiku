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

    build_part = record.build_part
    build = build_part.build_instance

    # Normally we would promote a ref after all the parts succeed, but in the case of maven
    # projects each individual part corresponds to a distinct promotable project. We want
    # to promote this even if another part fails since there are a lot of projects and
    # one is usually broken!
    if build.project.main_build? && build_part.successful?
      if promotion_ref = build.deployable_branch(build_part.paths.first)
        BranchUpdateJob.enqueue(build.id, promotion_ref)
      end
    end

    previous_state, new_state = build.update_state_from_parts!
    Rails.logger.info("Build #{build.id} state is now #{build.state}")
    unless previous_state == new_state
      BuildStateUpdateJob.enqueue(build.id)
    end
  end
end
