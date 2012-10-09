class BuildPart < ActiveRecord::Base
  belongs_to :build_instance, :class_name => "Build", :foreign_key => "build_id", :inverse_of => :build_parts    # using build_instance because AR defines #build for associations, and it wins
  has_many :build_attempts, :dependent => :destroy, :inverse_of => :build_part
  has_one :project, :through => :build_instance
  has_one :last_attempt, :class_name => "BuildAttempt", :order => "id DESC"
  validates_presence_of :kind, :paths

  serialize :paths, Array

  def create_and_enqueue_new_build_attempt!
    build_attempt = build_attempts.create!(:state => :runnable)
    job_args = {
      "build_attempt_id" => build_attempt.id,
      "build_kind" => self.kind,
      "build_ref" => build_instance.ref,
      "test_files" => self.paths,
      "repo_name" => self.project.repository.repository_name,
      "test_command" => self.project.repository.test_command,
      "repo_url" => self.project.repository.url,
    }
    BuildAttemptJob.enqueue_on("#{build_instance.queue}-#{self.kind}", job_args)
    build_attempt
  end

  def rebuild!
    create_and_enqueue_new_build_attempt!
  end

  def status
    last_attempt.try(:state) || "unknown"
  end

  def successful?
    build_attempts.any? &:successful?
  end

  def unsuccessful?
    !successful?
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

  def should_reattempt?
    build_attempts.unsuccessful.count <= 3 && kind == "cucumber" && (build_instance.auto_merge? || build_instance.queue == :ci)
  end
end
