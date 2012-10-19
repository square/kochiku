class Build < ActiveRecord::Base
  belongs_to :project, :inverse_of => :builds
  has_one :repository, :through => :project
  has_many :build_parts, :dependent => :destroy, :inverse_of => :build_instance do
    def last_attempt_in_state(*state)
      joins(:build_attempts).joins("LEFT JOIN build_attempts AS r ON build_attempts.build_part_id = r.build_part_id AND build_attempts.id < r.id").where("build_attempts.state" => state, "r.build_part_id" => nil)
    end
    def passed
      last_attempt_in_state(:passed)
    end
    def failed
      last_attempt_in_state(:failed)
    end
    def failed_or_errored
      last_attempt_in_state(:failed, :errored)
    end
    def errored
      last_attempt_in_state(:errored)
    end
  end
  has_many :build_attempts, :through => :build_parts
  TERMINAL_STATES = [:failed, :succeeded, :errored, :aborted]
  FAILED_STATES = [:failed, :errored, :doomed]
  IN_PROGRESS_STATES = [:partitioning, :runnable, :running, :doomed]
  STATES = IN_PROGRESS_STATES + TERMINAL_STATES
  symbolize :state, :in => STATES
  symbolize :queue
  validates_presence_of :queue
  validates_presence_of :project_id
  validates_presence_of :ref
  validates_uniqueness_of :ref, :scope => :project_id

  after_create :enqueue_partitioning_job

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
        build_parts.create!(:kind => part['type'], :paths => part['files'], :options => part['options'])
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
    if previous_state != state
      GithubCommitStatus.new(self).update_commit_status!
    end
  end

  def elapsed_time
    last_finished_at = build_attempts.maximum(:finished_at)
    return nil if last_finished_at.blank?
    last_finished_at - created_at
  end

  def succeeded?
    state == :succeeded
  end

  def failed?
    FAILED_STATES.include?(state)
  end

  def promotable?
    succeeded? && queue == :ci
  end

  def auto_mergable?
    succeeded? && auto_merge_enabled?
  end

  def auto_merge_enabled?
    queue == :developer && self.auto_merge
  end

  def auto_merge!
    BuildStrategy.merge_ref(self)
  end

  def promote!
    BuildStrategy.promote_build(self.ref, repository)
  end

  def completed?
    TERMINAL_STATES.include?(state)
  end

  def abort!
    update_attributes!(:state => :aborted)

    all_build_part_ids = build_parts.select('id').collect(&:id)
    BuildAttempt.update_all(
        {:state => :aborted, :updated_at => Time.now},
        {:state => :runnable, :build_part_id => all_build_part_ids}
    )
  end

  def to_png
    if state == :succeeded
      status_png(102, 255, 102) # green
    elsif [:failed, :errored, :aborted, :doomed].include?(state)
      status_png(255, 102, 102) # red
    else
      status_png(102, 102, 255) # blue
    end
  end

  def branch_or_ref
    branch.blank? ? ref : branch
  end
  private

  def status_png(r, g, b)
    ChunkyPNG::Canvas.new(13, 13, ChunkyPNG::Color::TRANSPARENT).
      circle(6, 6, 5, ChunkyPNG::Color::BLACK, ChunkyPNG::Color.rgb(r, g, b))
  end
end
