class BuildPart < ActiveRecord::Base
  # using 'build_instance' instead of 'build' because AR defines `build` for associations, and it wins
  belongs_to :build_instance, :class_name => "Build", :foreign_key => "build_id", :inverse_of => :build_parts, :touch => true
  has_many :build_attempts, :dependent => :destroy, :inverse_of => :build_part
  has_one :project, :through => :build_instance
  symbolize :queue
  validates_presence_of :kind, :paths, :queue

  serialize :paths, Array
  serialize :options, Hash

  def last_attempt
    build_attempts.last
  end

  def last_completed_attempt
    build_attempts.select { |bp| BuildAttempt::COMPLETED_BUILD_STATES.include?(bp.state) }.last
  end

  def create_and_enqueue_new_build_attempt!
    build_attempt = build_attempts.create!(:state => :runnable)
    build_instance.running!
    BuildAttemptJob.enqueue_on(queue.to_s, job_args(build_attempt))
    build_attempt
  end

  def job_args(build_attempt)
    {
        "build_attempt_id" => build_attempt.id,
        "build_kind" => kind,
        "build_ref" => build_instance.ref,
        "branch" => build_instance.branch,
        "test_files" => paths,
        "repo_name" => project.repository.repo_cache_name,
        "test_command" => build_instance.test_command,
        "repo_url" => project.repository.url_for_fetching,
        "remote_name" => "origin",
        "timeout" => project.repository.timeout.minutes,
        "options" => options,
        "kochiku_env" => Rails.env,
    }
  end

  def rebuild!
    create_and_enqueue_new_build_attempt!
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
    else
      nil
    end
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

  def last_stdout_artifact
    if artifacts = last_completed_attempt.try(:build_artifacts)
      artifacts.stdout_log.first
    end
  end

  def last_junit_artifact
    if artifacts = last_completed_attempt.try(:build_artifacts)
      artifacts.junit_log.first
    end
  end

  def last_junit_failures
    if junit_artifact = last_junit_artifact
      Zlib::GzipReader.open(junit_artifact.log_file.path) do |gz|
        xml = Nokogiri::XML.parse(gz)
        xml.xpath('//testcase[failure]')
      end
    end
  end
end
