class BuildPart < ActiveRecord::Base
  # using 'build_instance' instead of 'build' because AR defines `build` for associations, and it wins
  belongs_to :build_instance, :class_name => "Build", :foreign_key => "build_id", :inverse_of => :build_parts
  has_many :build_attempts, :dependent => :destroy, :inverse_of => :build_part
  symbolize :queue
  validates_presence_of :kind, :paths, :queue

  serialize :paths, Array
  serialize :options, Hash

  def last_attempt
    build_attempts.last
  end

  def create_and_enqueue_new_build_attempt!
    begin
      build_attempt = build_attempts.create!(:state => :runnable)
      BuildAttemptJob.enqueue_on(queue.to_s, job_args(build_attempt))
      build_instance.touch # invalidate the cache of builds#show
      build_attempt
    rescue GitRepo::RefNotFoundError
      # delete the dud build_attempt and re-raise
      build_attempt.destroy if build_attempt

      raise
    end
  end
  alias rebuild! create_and_enqueue_new_build_attempt!

  def job_args(build_attempt)
    repository = build_instance.repository
    {
      "build_attempt_id" => build_attempt.id,
      "build_kind" => kind,
      "build_ref" => build_instance.ref,
      "branch" => build_instance.branch_record.name,
      "test_files" => paths,
      "repo_name" => "#{repository.name}-cache",  # need to pass -cache for now for compatibility with current kochiku-worker
      "test_command" => build_instance.test_command,
      "repo_url" => repository.url_for_fetching,
      "remote_name" => "origin",
      "timeout" => repository.timeout.minutes,
      "options" => options,
      "kochiku_env" => Rails.env,
    }
  end

  def status
    if successful?
      :passed
    else
      last_attempt.try(:state) || :unknown
    end
  end

  def successful?
    build_attempts.any?(&:successful?)
  end

  def unsuccessful?
    !successful?
  end

  def running?
    started_at && !finished_at
  end

  def not_finished?
    !finished_at
  end

  def to_color
    case status
    when :passed
      :green
    when :failed, :errored, :aborted
      :red
    else
      :blue
    end
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
    end
  end

  def as_json(options={})
    super(options.reverse_merge(methods: :status))
  end

  def should_reattempt?
    if (build_attempts.unsuccessful.count - 1) < retry_count
      true
    # automatically retry build parts that errored in less than 60 seconds
    elsif elapsed_time && elapsed_time < 60 && last_attempt.errored? &&
          build_attempts.unsuccessful.count < 5
      true
    else
      false
    end
  end
end
