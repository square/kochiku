module ApplicationHelper
  def duration_strftime(duration_in_seconds, format = "%H:%M:%S")
    return "N/A" if duration_in_seconds.nil? ||
                    (duration_in_seconds.respond_to?(:nan?) && duration_in_seconds.nan?)
    (Time.mktime(0) + duration_in_seconds).strftime(format).sub(/^00[ :h]+0?/, "")
  end

  def time_for(time, format = "%H:%M")
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

  def link_to_commit(repo, commit_sha)
    link_to(commit_sha[0, 7], show_link_to_commit(repo, commit_sha))
  end

  def link_to_branch(build)
    branch_record = build.branch_record
    branch_name = branch_record.name
    link_to(branch_name, branch_record.repository.get_branch_url(branch_name))
  end

  def show_link_to_commit(repo, commit_sha)
    repo.remote_server.href_for_commit(commit_sha).to_s
  end

  def show_link_to_compare(build, first_commit_hash, second_commit_hash)
    repo = build.repository
    attrs_from_remote_server = RemoteServer.for_url(repo.url)

    if attrs_from_remote_server.class == RemoteServer::Stash
      second_commit_hash = repo.on_green_update.blank? ? "" : repo.on_green_update.split(',').first
    end
    attrs_from_remote_server.url_for_compare(first_commit_hash, second_commit_hash)
  end

  def show_link_to_create_pull_request(build)
    build.repository.open_pull_request_url(build.branch_record.name)
  end

  def timeago(time, options = {})
    options[:class] ||= "timeago"
    content_tag(:abbr, time.to_s, options.merge(:title => time.getutc.iso8601)) if time
  end
end
