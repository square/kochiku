class BuildPart < ActiveRecord::Base
  belongs_to :build_instance, :class_name => "Build", :foreign_key => "build_id", :inverse_of => :build_parts    # using build_instance because AR defines #build for associations, and it wins
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

  def self.most_recent_results_for(maven_modules)
    yaml_paths = maven_modules.map { |mvn_module| YAML.dump(Array(mvn_module)) }
    paths_to_ids = BuildPart.where(paths: yaml_paths).group(:paths).maximum(:id)
    BuildPart.find(paths_to_ids.values)
  end

  def create_and_enqueue_new_build_attempt!
    build_attempt = build_attempts.create!(:state => :runnable)
    build_instance.running!

    # TODO: hopefully this is only temporary while we work to make these tests less flaky
    # franklin should only be in this list until we get chromedriver installed on EC2
    # esperanto needs riak which is only on the macbuilds at the moment
    if (kind == "maven" && (paths.include?("franklin") ||
        paths.include?("esperanto") ||
        paths.include?("esperanto/riak") ||
        paths.include?("sake/rpc") ||
        paths.include?("clustering/zookeeper") ||
        paths.include?("openpgp") ||
        paths.include?("searle")))
      BuildAttemptJob.enqueue_on("ci-osx", job_args(build_attempt))
    else
      if build_instance.repository.queue_override
        BuildAttemptJob.enqueue_on(build_instance.repository.ci_queue_name, job_args(build_attempt))
      else
        BuildAttemptJob.enqueue_on(queue.to_s, job_args(build_attempt))
      end
    end

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
        "test_command" => build_instance.test_command(paths),
        "repo_url" => project.repository.url_for_fetching,
        "remote_name" => "origin",
        "timeout" => project.repository.timeout.minutes,
        "options" => options,
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

  def is_running?
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

  def is_for?(language)
    options['language'].to_s.downcase == language.to_s.downcase
  end

  def should_reattempt?
    build_attempts.unsuccessful.count < 3 &&
        (build_instance.auto_merge? || build_instance.project.main?) &&
        (kind == "cucumber" || kind == "maven" )
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
