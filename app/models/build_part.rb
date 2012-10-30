class BuildPart < ActiveRecord::Base
  belongs_to :build_instance, :class_name => "Build", :foreign_key => "build_id", :inverse_of => :build_parts    # using build_instance because AR defines #build for associations, and it wins
  has_many :build_attempts, :dependent => :destroy, :inverse_of => :build_part
  has_one :project, :through => :build_instance
  has_one :last_attempt, :class_name => "BuildAttempt", :order => "id DESC"
  validates_presence_of :kind, :paths

  serialize :paths, Array
  serialize :options, Hash

  def create_and_enqueue_new_build_attempt!
    build_attempt = build_attempts.create!(:state => :runnable)
    job_args = {
      "build_attempt_id" => build_attempt.id,
      "build_kind" => self.kind,
      "build_ref" => build_instance.ref,
      "test_files" => self.paths,
      "repo_name" => self.project.repository.repo_cache_name,
      "test_command" => self.build_instance.test_command(self.paths),
      "repo_url" => self.project.repository.url,
      "options" => self.options,
    }
    # TODO: this is a hack, please fix the following and restore this code to it's former glory.
    # We need to do 2 things before enabling this:
    # 1) update the ssh key on ec2 builders
    # 2) get more space on the ec2 builders
    if build_instance.repository.use_spec_and_ci_queues
      BuildAttemptJob.enqueue_on("#{build_instance.queue}-#{self.kind}", job_args)
    else
      BuildAttemptJob.enqueue_on(build_instance.repository.ci_queue_name, job_args)
    end
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

  def is_for?(language)
    options['language'].to_s.downcase == language.to_s.downcase
  end

  def should_reattempt?
    build_attempts.unsuccessful.count <= 3 && kind == "cucumber" && (build_instance.auto_merge? || build_instance.queue == :ci)
  end
end
