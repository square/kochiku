module BuildHelper
  def build_metadata_headers(build, display_ruby_version)
    headers = []
    headers << "Ruby Version" if display_ruby_version

    if is_a_build_with_one_part?(build)
      headers << "Target"
    else
      headers << "Paths"
    end
    headers
  end

  def build_metadata_values(build, build_part, display_ruby_version)
    values = []
    values << build_part.options["ruby"] if display_ruby_version
    values << format_paths(build_part)
    values
  end

  def format_paths(build_part)
    if (build_part.options['total_workers'] && build_part.options['worker_chunk'])
      build_part.paths.first + " - Chunk #{build_part.options['worker_chunk']} of #{build_part.options['total_workers']}"
    elsif build_part.paths.size == 1
      build_part.paths.first
    else
      first, *rest = build_part.paths
      first = first.sub(/([^\/]+)/, '<b class="root">\1</b>')
      paths = [first, rest].join(', ')
      "#{build_part.paths.length} <span class=\"paths\" title=\"#{build_part.paths.join(', ')}\">(#{paths})</span>".html_safe
    end
  end

  def multiple_ruby_versions?(build)
    build.build_parts.map { |bp| bp.options['ruby'] }.compact.uniq.size > 1
  end

  def is_a_build_with_one_part?(build)
    build.build_parts.none? {|build_part| build_part.paths.size > 1 }
  end

  def eligible_for_merge_on_success?(build)
    !build.succeeded? && !build.branch_record.convergence? && build.repository.allows_kochiku_merges?
  end
end
