module MailHelper
  def failed_build_part_sentence(build_part)
    stdout_log = build_part.most_recent_stdout_artifact
    str = "failed after #{build_part.elapsed_time.to_i / 60} minutes"
    if stdout_log
      str += ", for details you can go directly to the #{link_to('stdout', build_artifact_url(stdout_log))} log."
    end
    str.html_safe
  end

  def failed_build_paths(build_part)
    paths = build_part.paths

    str = if build_part.kind.include?('spec')
            paths.map { |path| path.split('/').last }
          else
            paths
          end

    str.join(', ').truncate(200)
  end
end
