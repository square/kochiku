module ApplicationHelper
  def duration_strftime(duration_in_seconds, format="%H:%M:%S")
    (Time.mktime(0)+duration_in_seconds).strftime(format)
  end
end
