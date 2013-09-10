class BuildAttempt < ActiveRecord::Base
  has_many :build_artifacts, :dependent => :destroy, :inverse_of => :build_attempt
  belongs_to :build_part, :inverse_of => :build_attempts

  FAILED_BUILD_STATES = [:failed, :errored]
  COMPLETED_BUILD_STATES = [:passed, :aborted] + FAILED_BUILD_STATES
  IN_PROGRESS_BUILD_STATES = [:runnable, :running]
  STATES = IN_PROGRESS_BUILD_STATES + COMPLETED_BUILD_STATES

  symbolize :state, :in => STATES, :scopes => true

  scope :unsuccessful, -> { where(state: FAILED_BUILD_STATES) }

  def elapsed_time
    if finished_at && started_at
      finished_at - started_at
    elsif started_at
      Time.now - started_at
    else
      nil
    end
  end

  def start!(builder)
    return false unless update_attributes(:state => :running, :started_at => Time.now, :builder => builder)

    build = build_part.build_instance
    previous_state, new_state = build.update_state_from_parts!
    Rails.logger.info("Build #{build.id} state is now #{build.state}")
    if previous_state != new_state
      BuildStateUpdateJob.enqueue(build.id)
    end

    true
  end

  def finish!(state)
    return false unless update_attributes(:state => state, :finished_at => Time.now)

    if should_reattempt?
      build_part.rebuild!
    elsif state == :errored
      BuildMailer.error_email(self, error_txt).deliver
    end

    build = build_part.build_instance

    previous_state, new_state = build.update_state_from_parts!
    Rails.logger.info("Build #{build.id} state is now #{build.state}")
    if previous_state != new_state
      BuildStateUpdateJob.enqueue(build.id)
    end

    true
  end

  def unsuccessful?
    FAILED_BUILD_STATES.include?(state)
  end

  def successful?
    state == :passed
  end

  def aborted?
    state == :aborted
  end

  def running?
    state == :running
  end

  def should_reattempt?
    unsuccessful? && build_part.should_reattempt?
  end

  def error_txt
    if error_artifact = build_artifacts.error_txt.first
      File.read(error_artifact.log_file.path)
    end
  end
end
