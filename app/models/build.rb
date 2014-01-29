require 'on_success_uploader'
require 'fileless_io'

class Build < ActiveRecord::Base
  belongs_to :project, :inverse_of => :builds
  has_one :repository, :through => :project
  has_many :build_parts, :dependent => :destroy, :inverse_of => :build_instance do
    def not_passed_and_last_attempt_in_state(*state)
      joins(:build_attempts).joins(<<-EOSQL).where("build_attempts.state" => state, "passed_attempt.id" => nil, "newer_attempt.id" => nil)
        LEFT JOIN build_attempts
          AS passed_attempt
          ON build_attempts.build_part_id = passed_attempt.build_part_id
            AND passed_attempt.state = 'passed'
        LEFT JOIN build_attempts
          AS newer_attempt
          ON build_attempts.build_part_id = newer_attempt.build_part_id
            AND newer_attempt.id > build_attempts.id
      EOSQL
    end
    def passed
      joins(:build_attempts).where("build_attempts.state" => :passed).group("build_parts.id")
    end
    def failed
      not_passed_and_last_attempt_in_state(:failed)
    end
    def failed_or_errored
      not_passed_and_last_attempt_in_state(:failed, :errored)
    end
    def failed_errored_or_aborted
      not_passed_and_last_attempt_in_state(:failed, :errored, :aborted)
    end
    def errored
      not_passed_and_last_attempt_in_state(:errored)
    end
  end
  has_many :build_attempts, :through => :build_parts
  TERMINAL_STATES = [:failed, :succeeded, :errored, :aborted]
  FAILED_STATES = [:failed, :errored, :doomed]
  IN_PROGRESS_STATES = [:waiting_for_sync, :partitioning, :runnable, :running, :doomed]
  STATES = IN_PROGRESS_STATES + TERMINAL_STATES
  symbolize :state, :in => STATES
  serialize :error_details, Hash

  validates_presence_of :project_id
  validates_presence_of :ref
  validates_uniqueness_of :ref, :scope => :project_id
  mount_uploader :on_success_script_log_file, OnSuccessUploader

  after_commit :enqueue_partitioning_job, :on => :create

  scope :completed, -> { where(state: TERMINAL_STATES) }
  scope :successful_for_project, lambda { |project_id| where(:project_id => project_id, :state => :succeeded) }

  def test_command(run_list)
    command = repository.test_command
    command += " #{repository.command_flag}" unless run_list.include?(target_name)
    command
  end

  def previous_successful_build
    Build.successful_for_project(project_id).order("id DESC").where("id < ?", self.id).first
  end

  def enqueue_partitioning_job
    Resque.enqueue(BuildPartitioningJob, self.id)
  end

  def partition(parts)
    transaction do
      update_attributes!(:state => :runnable)
      parts.each do |part|
        build_parts.create!(:kind => part['type'],
                            :paths => part['files'],
                            :queue => part['queue'],
                            :retry_count => part['retry_count'],
                            :options => part['options'])
      end
    end

    build_parts.each { |build_part| build_part.create_and_enqueue_new_build_attempt! }
  end

  def update_state_from_parts!
    return if build_parts.empty? || self.state == :aborted

    errored = build_parts.errored
    passed = build_parts.passed
    failed = build_parts.failed

    state = case
      when errored.any?
        :errored
      when (build_parts - passed).empty?
        :succeeded
      when (passed | failed).count == build_parts.count
        :failed
      else
        failed.empty? ? :running : :doomed
      end

    previous_state = self.state
    update_attributes!(:state => state)
    [previous_state, state]
  end

  def finished_at
    build_attempts.maximum(:finished_at)
  end

  def elapsed_time
    last_finished_at = finished_at
    return nil if last_finished_at.blank?
    last_finished_at - created_at
  end

  def succeeded?
    state == :succeeded
  end

  def failed?
    FAILED_STATES.include?(state)
  end

  def aborted?
    state == :aborted
  end

  def promotable?
    succeeded? && project.main?
  end

  def auto_mergable?
    succeeded? && auto_merge_enabled? && repository.allows_kochiku_merges?
  end

  def auto_merge_togglable?
    !succeeded? && !project.main?
  end

  def auto_merge_enabled?
    !project.main? && self.auto_merge
  end

  def auto_merge!
    BuildStrategy.merge_ref(self)
  end

  def promote!
    BuildStrategy.promote_build(ref, repository)
    if repository.has_on_success_script? &&
        !promoted? &&
        Build.where(id: self.id, promoted: nil).update_all(promoted: true) == 1
      output = BuildStrategy.run_success_script(repository, ref, branch)
      script_log = FilelessIO.new(output)
      script_log.original_filename = "on_success_script.log"
      self.on_success_script_log_file = script_log
      self.save!
    end
  end

  def add_note!
    BuildStrategy.add_note(ref, "ci-#{project.name}", repository.on_success_note)
  end

  def completed?
    TERMINAL_STATES.include?(state)
  end

  def abort!
    update_attributes!(:state => :aborted)

    all_build_part_ids = build_parts.select('id').collect(&:id)
    BuildAttempt.
        where(state: :runnable, build_part_id: all_build_part_ids).
        update_all(state: :aborted, updated_at: Time.now)
  end

  def to_color
    case state
    when :succeeded
      :green
    when :failed, :errored, :aborted, :doomed
      :red
    else
      :blue
    end
  end

  def to_png
    case to_color
    when :green
      status_png(179, 247, 110)
    when :red
      status_png(247, 110, 110)
    when :blue
      status_png(110, 165, 247)
    end
  end

  def branch_or_ref
    branch.blank? ? ref : branch
  end

  def send_build_status_email!
    return if (project.main? && !previous_successful_build) || !repository.send_build_failure_email?

    if completed? && failed? && !build_failure_email_sent?
      if Build.where(id: self.id, build_failure_email_sent: nil).update_all(build_failure_email_sent: true) == 1
        BuildMailer.build_break_email(self).deliver
      end
    end
  end

  def running!
    if %w(runnable partitioning).include?(state.to_s)
      update_attributes!(:state => :running)
    end
  end

  def is_running?
    IN_PROGRESS_STATES.include?(self.state)
  end

  def junit_failures
    # TODO fix n+1
    build_parts.map(&:last_junit_failures).flatten
  end

  private

  def status_png(r, g, b)
    ChunkyPNG::Canvas.new(13, 13, ChunkyPNG::Color::TRANSPARENT).
      circle(6, 6, 5, ChunkyPNG::Color::BLACK, ChunkyPNG::Color.rgb(r, g, b))
  end
end
