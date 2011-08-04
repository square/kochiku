class Build < ActiveRecord::Base
  belongs_to :project, :inverse_of => :builds
  has_many :build_parts, :dependent => :destroy, :inverse_of => :build_instance do
    def last_attempt_in_state(state)
      joins(:build_attempts).joins("LEFT JOIN build_attempts AS r ON build_attempts.build_part_id = r.build_part_id AND build_attempts.id < r.id").where("build_attempts.state" => state, "r.build_part_id" => nil)
    end
    def passed
      last_attempt_in_state(:passed)
    end
    def failed
      last_attempt_in_state(:failed)
    end
    def errored
      last_attempt_in_state(:errored)
    end
  end
  has_many :build_attempts, :through => :build_parts
  TERMINAL_STATES = [:failed, :succeeded, :errored]
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
      parts.each do |part|
        build_parts.create!(:kind => part['type'], :paths => part['files'])
      end
    end

    build_parts.each { |build_part| build_part.create_and_enqueue_new_build_attempt! }
  end

  def update_state_from_parts!
    return if build_parts.empty?

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
    update_attributes!(:state => state)
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
