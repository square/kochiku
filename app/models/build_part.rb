class BuildPart < ActiveRecord::Base
  has_many :build_attempts
  belongs_to :build
  after_commit :enqueue_build_part_job
  validates_presence_of :kind, :paths

  serialize :paths, Array

  scope :failed, joins(:build_attempts).merge(BuildAttempt.failed)
  scope :passed, joins(:build_attempts).merge(BuildAttempt.passed)

  def enqueue_build_part_job
    build_attempt = build_attempts.create!(:state => :runnable)
    BuildPartJob.enqueue_on(build.queue, build_attempt.id)
  end

  def rebuild!
    enqueue_build_part_job
  end

  def status
    build_attempts.order(:created_at).last.state
  end

  def execute
    BuildStrategy.new.execute_build(self)
  end

  def artifacts_glob
    BuildStrategy.new.artifacts_glob
  end

  def started_at
    build_attempts.last.try(:started_at)
  end

  def finished_at
    build_attempts.last.try(:finished_at)
  end

  def elapsed_time
    if finished_at && started_at
      finished_at - started_at
    elsif started_at
      Time.now - started_at
    else
      nil
    end
  end
end
