require 'job_base'

# Keep this interface so we can easily enqueue new jobs.
# The job is handled by kochiku-worker
class BuildAttemptJob < JobBase
  class WrongBuildAttemptJobClassError < StandardError; end

  def initialize(build_options)
    raise WrongBuildAttemptJobClassError, "BuildAttemptJob was processed by the BuildAttemptJob shim in Kochiku instead of real class in Kochiku-worker."
  end

  def perform
  end
end
