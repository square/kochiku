module ApplicationHelper
  def duration_strftime(duration_in_seconds, format="%H:%M:%S")
    return "N/A" if duration_in_seconds.nil? ||
      (duration_in_seconds.respond_to?(:nan?) && duration_in_seconds.nan?)
    (Time.mktime(0) + duration_in_seconds).strftime(format).sub(/^00[ :h]+0?/, "")
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

  def link_to_commit(build)
    link_to build.ref[0,7], show_link_to_commit(build)
  end

  def link_to_branch(build)
    link_to build.branch_record.name, show_link_to_branch(build.branch_record)
  end

  def show_link_to_commit(build)
    "#{build.repository.remote_server.href_for_commit(build.ref)}"
  end

  # TODO: Extract these links into RemoteServer
  def show_link_to_branch(branch_record)
    "#{branch_record.repository.base_html_url}/tree/#{branch_record.name}"
  end

  def show_link_to_compare(build, first_commit_hash, second_commit_hash)
    repo = build.repository
    attrs_from_remote_server = RemoteServer.for_url(repo.url)

    if attrs_from_remote_server.class == RemoteServer::Stash
      if repo.on_green_update.blank?
        second_commit_hash = ""
      else
        second_commit_hash = repo.on_green_update.split(',').first
      end
    end
    attrs_from_remote_server.url_for_compare(first_commit_hash, second_commit_hash)
  end

  def show_link_to_create_pull_request(build)
    "#{build.repository.base_html_url}/pull/new/master...#{build.ref}"
  end

  def failed_build_stdout(failed_build_part)
    failed_build_attempt = failed_build_part.build_attempts.unsuccessful.last
    stdout_build_artifact_id = failed_build_attempt.build_artifacts.stdout_log.first.id
    "#{Settings.kochiku_host_with_protocol}/build_artifacts/#{stdout_build_artifact_id}"
  end

  def timeago(time, options = {})
    options[:class] ||= "timeago"
    content_tag(:abbr, time.to_s, options.merge(:title => time.getutc.iso8601)) if time
  end
end
