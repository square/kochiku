require 'on_success_uploader'
require 'fileless_io'
require 'build_partitioning_job'

class Build < ActiveRecord::Base
  # using 'branch_record' instead of 'branch' because Build has a legacy 'branch' string type column. The legacy column will be removed soon.
  belongs_to :branch_record, :class_name => "Branch", :foreign_key => "branch_id", :inverse_of => :builds, :touch => true
  has_one :repository, :through => :branch_record
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

    def all_passed_on_first_try?
      successful_build_attempts = joins(:build_attempts).where("build_attempts.state" => :passed).count
      unsuccessful_build_attempts = joins(:build_attempts).where("build_attempts.state != ?", :passed).count
      successful_build_attempts > 0 && unsuccessful_build_attempts == 0
    end
  end
  has_many :build_attempts, :through => :build_parts
  TERMINAL_STATES = [:failed, :succeeded, :errored, :aborted]
  FAILED_STATES = [:failed, :errored, :doomed]
  IN_PROGRESS_STATES = [:waiting_for_sync, :partitioning, :runnable, :running, :doomed]
  STATES = IN_PROGRESS_STATES + TERMINAL_STATES
  symbolize :state, :in => STATES
  serialize :error_details, Hash

  validates :branch_id, presence: true
  validates :ref, presence: true,
                  length: { is: 40, allow_blank: true },
                  uniqueness: { scope: :branch_id, allow_blank: true }

  mount_uploader :on_success_script_log_file, OnSuccessUploader

  after_commit :enqueue_partitioning_job, :on => :create

  scope :completed, -> { where(state: TERMINAL_STATES) }

  def test_command
    (kochiku_yml && kochiku_yml.key?('test_command')) ? kochiku_yml['test_command'] : repository.test_command
  end

  def on_success_script
    (kochiku_yml && kochiku_yml.key?('on_success_script')) ? kochiku_yml['on_success_script'] : nil
  end

  def previous_build
    branch_record.builds.where("id < ?", self.id).order("id DESC").first
  end

  def previous_successful_build
    Build.where(branch_id: self.branch_id, state: :succeeded).where("id < ?", self.id).order("id DESC").first
  end

  def enqueue_partitioning_job
    Resque.enqueue(BuildPartitioningJob, self.id)
  end

  def kochiku_yml
    if @kochiku_yml.nil?
      @kochiku_yml = GitRepo.load_kochiku_yml(repository, ref) || false
    else
      @kochiku_yml
    end
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
    return if build_parts.empty?

    errored = build_parts.errored
    passed = build_parts.passed
    failed = build_parts.failed

    next_state = case
                 when (build_parts - passed).empty?
                   :succeeded
                 when self.state == :aborted
                   :aborted
                 when errored.any?
                   :errored
                 when (passed | failed).count == build_parts.count
                   :failed
                 else
                   failed.empty? ? :running : :doomed
                 end

    previous_state = self.state
    update_attributes!(:state => next_state) unless previous_state == next_state
    [previous_state, next_state]
  end

  def update_commit_status!
    repository.remote_server.update_commit_status!(self)
  end

  # As implemented, finished_at will return the wrong value if there is a
  # unsuccessful attempt following a successful one. Left this way for
  # performance and simplicity.
  def finished_at
    build_attempts.maximum(:finished_at)
  end

  def elapsed_time
    last_finished_at = finished_at
    return nil if last_finished_at.blank?
    last_finished_at - created_at
  end

  def linear_time
    build_parts.inject(0) do |sum, part|
      sum + (part.elapsed_time || 0)
    end
  end

  def retry_count
    build_parts.sum(0) do |part|
      part.build_attempts.count - 1
    end
  end

  def max_retries
    build_parts.max_by { |part| part.build_attempts.count }.build_attempts.count - 1
  end

  # This can be used as `building_time` under the assumption that
  # all parts executed in parallel.
  def longest_build_part
    build_parts.max_by { |part| part.elapsed_time || 0 }.elapsed_time
  end

  def idle_time
    (elapsed_time || 0) - (longest_build_part || 0)
  end

  def succeeded?
    state == :succeeded
  end

  def failed?
    FAILED_STATES.include?(state)
  end

  # has a build part with failed attempts but no successful ones yet
  def already_failed?
    build_parts.any? { |part| part.build_attempts.unsuccessful.exists? && !part.build_attempts.where(state: :passed).exists? }
  end

  def aborted?
    state == :aborted
  end

  def promotable?
    succeeded? && branch_record.convergence?
  end

  def mergable_by_kochiku?
    succeeded? && merge_on_success_enabled? && repository.allows_kochiku_merges? && !newer_branch_build_exists?
  end

  def merge_on_success_enabled?
    !branch_record.convergence? && self.merge_on_success
  end

  def newer_branch_build_exists?
    most_recent_build = branch_record.most_recent_build
    most_recent_build.id != self.id
  end

  def merge_to_master!
    BuildStrategy.merge_ref(self)
  end

  def promote!
    unless promoted?
      BuildStrategy.promote_build(self)
      update!(promoted: true)
    end
  end

  def completed?
    TERMINAL_STATES.include?(state)
  end

  # Changes the build state to 'aborted'. Sets merge_on_success to false to
  # protect against accidental merges. Updates the state of all of the build's
  # build_parts to be 'aborted'.
  def abort!
    update!(state: :aborted, merge_on_success: false)

    all_build_part_ids = build_parts.select([:id, :build_id]).collect(&:id)
    BuildAttempt
      .where(state: :runnable, build_part_id: all_build_part_ids)
      .update_all(state: :aborted, updated_at: Time.now)
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

  def send_build_status_email!
    return if branch_record.convergence? && !previous_successful_build

    if completed?
      if failed? && !build_failure_email_sent? && repository.send_build_failure_email?
        unless build_failure_email_sent?
          BuildMailer.build_break_email(self).deliver_now
          update(build_failure_email_sent: true)
        end
      elsif succeeded? && !branch_record.convergence? && !build_success_email_sent? && repository.send_build_success_email?
        BuildMailer.build_success_email(self).deliver_now
        update(build_success_email_sent: true)
      end
    elsif !branch_record.convergence? && repository.email_on_first_failure && already_failed? && repository.send_build_failure_email?
      unless build_failure_email_sent?
        # due to race condition, update attribute before sending email
        update(build_failure_email_sent: true)
        BuildMailer.build_break_email(self).deliver_now
      end
    end
  end

  def running!
    if [:runnable, :partitioning].include?(self.state)
      update_attributes!(:state => :running)
    end
  end

  def is_running?
    IN_PROGRESS_STATES.include?(self.state)
  end

  def junit_failures
    # TODO: fix n+1
    build_parts.map(&:last_junit_failures).flatten
  end

  private

  def status_png(r, g, b)
    ChunkyPNG::Canvas.new(13, 13, ChunkyPNG::Color::TRANSPARENT)
      .circle(6, 6, 5, ChunkyPNG::Color::BLACK, ChunkyPNG::Color.rgb(r, g, b))
  end
end
