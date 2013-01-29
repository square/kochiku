require 'job_base'

class BuildAttemptJob < JobBase
  def initialize(build_attempt_id, build_kind, build_ref, test_files)
    # Keep this interface so we can easily enqueue new jobs.
    # The job is handled by kochiku-worker
  end

  def perform
  end
end
