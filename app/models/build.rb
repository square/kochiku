class Build < ActiveRecord::Base
  belongs_to :project, :inverse_of => :builds
  has_many :build_parts, :dependent => :destroy, :inverse_of => :build_instance do
    def passed
      joins(:build_attempts).where('build_attempts.state' => 'passed')
    end
    def failed
      joins(:build_attempts).where('build_attempts.state' => 'failed')
    end
    def errored
      joins(:build_attempts).where('build_attempts.state' => 'error')
    end
  end
  has_many :build_attempts, :through => :build_parts
  TERMINAL_STATES = [:failed, :succeeded, :error]
  STATES = [:partitioning, :runnable, :running, :doomed] + TERMINAL_STATES
  symbolize :state, :in => STATES
  symbolize :queue
  validates_presence_of :queue
  validates_presence_of :project_id
  validates_presence_of :ref

  after_create :enqueue_partitioning_job

  def enqueue_partitioning_job
    Resque.enqueue(BuildPartitioningJob, self.id)
  end

  def partition(parts)
    transaction do
      update_attributes!(:state => :runnable)
      parts.each { |part| build_parts.create!(:kind => part['type'], :paths => part['files']) }
    end
  end

  def update_state_from_parts!
    return if build_parts.empty?

    errored = build_parts.errored
    passed = build_parts.passed
    failed = build_parts.failed

    state = case
      when errored.any?
        :error
      when (build_parts - passed).empty?
        :succeeded
      when (passed | failed).count == build_parts.count
        :failed
      else
        failed.empty? ? :running : :doomed
      end
    update_attributes!(:state => state)
  end

  def started_at
    build_attempts.order('started_at asc').first.started_at
  end

  def finished_at
    build_attempts.all.sort_by(&:finished_at).last
  end

  def elapsed_time
    last_finished_at = build_attempts.maximum(:finished_at)
    return nil if last_finished_at.blank?
    last_finished_at - created_at
  end

  def succeeded?
    state == :succeeded
  end

  def promotable?
    succeeded? && queue == :ci
  end

  def promote!
    BuildStrategy.promote_build(self.ref)
  end

  def completed?
    TERMINAL_STATES.include?(state)
  end
end
