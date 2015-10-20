class BuildPartDecorator < Draper::Decorator
  delegate_all

  def most_recent_stdout_artifact
    BuildArtifact
      .joins(:build_attempt => :build_part)
      .where(
        'build_attempts.build_part_id' => object.id,
        'build_attempts.state' => BuildAttempt::COMPLETED_BUILD_STATES
      ).stdout_log.last
  end
end
