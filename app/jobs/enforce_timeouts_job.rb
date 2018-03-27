# The EnforceTimeoutsJob searches for BuildAttempts that were picked up by a
# kochiku worker but never heard back from again. It compares (Time.now -
# started_at) against the timeout value of the repository. If the maximum time
# has elapsed, it will mark the BuildAttempt as errored and kick off a rebuild.
class EnforceTimeoutsJob
  def self.perform
    # The EnforceTimeoutsJob runs frequently so we do not check BuildAttempts greater than 1 day old
    BuildAttempt.where("created_at > ? AND state = 'running' AND started_at IS NOT NULL", 1.day.ago).each do |attempt|
      lenient_timeout = attempt.build_instance.repository.timeout + 5
      if attempt.elapsed_time > lenient_timeout.minutes
        # Error artifact creation taken from kochiku-worker
        message = StringIO.new
        message.puts("This BuildAttempt has not been updated by its worker,\n" \
                     "and has been running longer then the timeout so it has\n" \
                     "been considered lost by Kochiku.")
        message.rewind
        def message.path
          'error.txt'
        end

        BuildArtifact.create(:build_attempt_id => attempt.id, :log_file => message)
        attempt.update!(state: 'errored', finished_at: Time.current)
        Rails.logger.error "Errored BuildAttempt:#{attempt.id} due to timeout"

        # Enqueue another BuildAttempt if this is the most recent attempt for the BuildPart
        part = attempt.build_part
        part.rebuild! if part.build_attempts.last == attempt
      end
    end
  end
end
