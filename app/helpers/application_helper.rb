module ApplicationHelper
  def duration_strftime(duration_in_seconds, format="%H:%M:%S")
    return "N/A" if duration_in_seconds.nil?
    (Time.mktime(0)+duration_in_seconds).strftime(format)
  end

  def build_success_in_words(build)
    case build.state
    when :succeeded
      'success'
    when :errored, :doomed
      'failed'
    else
      build.state.to_s
    end
  end
  
  def build_activity(build)
    return "Unknown" unless build.is_a?(Build)

    case build.state
    when :partitioning, :runnable, :running
      "Building"
    when :doomed, :failed, :succeeded, :errored
      "CheckingModifications"
    end
  end
end
