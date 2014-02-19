class ProjectDecorator < Draper::Decorator
  delegate_all

  def most_recent_build
    @most_recent_build ||= object.builds.last
  end

  def most_recent_build_state
    most_recent_build.try(:state) || :unknown
  end

  def last_completed_build
    @last_completed_build ||= object.builds.completed.last
  end

  def last_build_duration
    last_completed_build.try(:elapsed_time)
  end

end
