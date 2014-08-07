class EnforceTimeoutsJob
  def self.perform
    BuildAttempt.where(:state => 'running').each do |attempt|
      lenient_timeout = attempt.build_instance.project.repository.timeout + 15
      if attempt.elapsed_time > lenient_timeout.minutes
        # Error artifact creation taken from kochiku-worker
        message = StringIO.new
        message.puts("This BuildAttempt has not been updated by its worker,\n" +
                     "but the build taken longer than the project's timeout.")
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
