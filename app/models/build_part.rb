class BuildPart < ActiveRecord::Base
  belongs_to :build_instance, :class_name => "Build", :foreign_key => "build_id", :inverse_of => :build_parts    # using build_instance because AR defines #build for associations, and it wins
  has_many :build_attempts, :dependent => :destroy, :inverse_of => :build_part
  has_one :project, :through => :build_instance
  has_one :last_attempt, :class_name => "BuildAttempt", :order => "id DESC"
  after_commit :enqueue_build_part_job, :on => :create
  validates_presence_of :kind, :paths

  serialize :paths, Array

  def enqueue_build_part_job
    build_attempt = build_attempts.create!(:state => :runnable)
    BuildPartJob.enqueue_on(build_instance.queue, build_attempt.id)
  end

  def rebuild!
    enqueue_build_part_job
  end

  def status
    last_attempt.state
  end

  def unsuccessful?
    last_attempt.unsuccessful?
  end

  def execute
    BuildStrategy.execute_build(self)
  end

  def artifacts_glob
    BuildStrategy.artifacts_glob
  end

  def started_at
    last_attempt.try(:started_at)
  end

  def finished_at
    last_attempt.try(:finished_at)
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
