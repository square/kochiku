module ApplicationHelper
  def duration_strftime(duration_in_seconds, format="%H:%M:%S")
    return "N/A" if duration_in_seconds.nil?
    (Time.mktime(0)+duration_in_seconds).strftime(format).sub(/^00[ :h]+0?/, "")
  end

  def time_for(time, format="%H:%M")
    time.strftime(format)
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

  def show_link_to_commit(build)
    "#{build.repository.base_html_url}/commit/#{build.ref}"
  end

  def show_link_to_compare(build, first_commit_hash, second_commit_hash)
    "#{build.repository.base_html_url}/compare/#{first_commit_hash}...#{second_commit_hash}#files_bucket"
  end

  def show_link_to_create_pull_request(build)
    "#{build.repository.base_html_url}/pull/new/square:master...#{build.ref}"
  end

  def failed_build_stdout(failed_build_part)
    build = failed_build_part.build_instance
    failed_build_attempt = failed_build_part.build_attempts.unsuccessful.last
    link_to("stdout.log.gz", "http://macbuild-master.sfo.squareup.com/log_files/#{build.project.to_param}/build_#{build.id}/part_#{failed_build_part.id}/attempt_#{failed_build_attempt.id}/stdout.log.gz")
  end
end
