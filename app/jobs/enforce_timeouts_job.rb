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
        attempt.finish!(:errored)
        Rails.logger.error "Errored BuildAttempt:#{ attempt.id } due to timeout"
      end
    end
  end
end
