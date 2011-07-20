class BuildPart < ActiveRecord::Base
  belongs_to :build_instance, :class_name => "Build", :foreign_key => "build_id"    # using build_instance because AR defines #build for associations, and it wins
  has_many :build_attempts, :dependent => :destroy
  has_one :project, :through => :build_instance
  after_commit :enqueue_build_part_job
  validates_presence_of :kind, :paths

  serialize :paths, Array

  scope :failed, joins(:build_attempts).merge(BuildAttempt.failed)
  scope :passed, joins(:build_attempts).merge(BuildAttempt.passed)

  def enqueue_build_part_job
    build_attempt = build_attempts.create!(:state => :runnable)
    BuildPartJob.enqueue_on(build_instance.queue, build_attempt.id)
  end

  def rebuild!
    enqueue_build_part_job
  end

  def last_attempt
    build_attempts.order(:created_at).last
  end

  def status
    last_attempt.state
  end

  def unsuccessful?
    last_attempt.unsuccessful?
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
