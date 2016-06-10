class BuildAttempt < ActiveRecord::Base
  has_many :build_artifacts, :dependent => :destroy, :inverse_of => :build_attempt
  belongs_to :build_part, :inverse_of => :build_attempts, :touch => true
  has_one :build_instance, through: :build_part

  FAILED_BUILD_STATES = [:failed, :errored].freeze
  COMPLETED_BUILD_STATES = [:passed, :aborted] + FAILED_BUILD_STATES
  IN_PROGRESS_BUILD_STATES = [:runnable, :running].freeze
  STATES = IN_PROGRESS_BUILD_STATES + COMPLETED_BUILD_STATES

  symbolize :state, :in => STATES, :scopes => true

  scope :unsuccessful, -> { where(state: FAILED_BUILD_STATES) }

  def elapsed_time
    if finished_at && started_at
      finished_at - started_at
    elsif started_at
      Time.current - started_at
    end
  end

  def start!(builder)
    return false unless update_attributes(:state => :running, :started_at => Time.current, :builder => builder)

    build = build_part.build_instance
    previous_state, new_state = build.update_state_from_parts!

    if previous_state == new_state
      # bump build's update_at because update_state_from_parts did not alter the build record
      build.touch
    end

    if previous_state != new_state
      Rails.logger.info("Build #{build.id} state is now #{build.state}")
      BuildStateUpdateJob.enqueue(build.id)
    end

    true
  end

  def finish!(state)
    return false unless update_attributes(:state => state, :finished_at => Time.current)

    if should_reattempt?
      # Will only send email if email_on_first_failure is enabled.
      build_part.build_instance.send_build_status_email!
      build_part.rebuild!
    elsif state == :errored
      BuildMailer.error_email(self, error_txt).deliver_now
    end

    build = build_part.build_instance

    previous_state, new_state = build.update_state_from_parts!

    if previous_state == new_state
      # bump build's update_at because update_state_from_parts did not alter the build record
      build.touch
    end

    if previous_state != new_state
      Rails.logger.info("Build #{build.id} state is now #{build.state}")
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

  def stopped?
    COMPLETED_BUILD_STATES.include?(state)
  end

  def errored?
    state == :errored
  end

  def should_reattempt?
    unsuccessful? && build_part.should_reattempt?
  end

  def error_txt
    error_artifact = build_artifacts.error_txt.first
    error_artifact.log_file.read if error_artifact
  end
end
