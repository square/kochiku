module ApplicationHelper
  def duration_strftime(duration_in_seconds, format="%H:%M:%S")
    return "N/A" if duration_in_seconds.nil?
    (Time.mktime(0)+duration_in_seconds).strftime(format)
  end

  def build_success_in_words(build)
    case build.state
    when :succeeded
      'success'
    when :error, :doomed
      'failed'
    else
      build.state.to_s
    end
  end
end
