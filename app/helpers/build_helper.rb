module BuildHelper
  def build_metadata_headers(build)
    [].tap do |headers|
      headers << "Ruby Version" if is_a_ruby_build?(build)

      if is_a_build_with_one_part?(build)
        headers << "Target"
      else
        headers << "Paths"
      end
    end
  end

  def build_metadata_values(build, build_part)
    [].tap do |values|
      values << build_part.options["ruby"] if is_a_ruby_build?(build)

      if build_part.paths.size == 1
        values << build_part.paths.first
      else
        first, *rest = build_part.paths
        first = first.sub(/([^\/]+)/, '<b class="root">\1</b>')
        paths = [first, rest].join(', ')
        values << "#{build_part.paths.length} <span class=\"paths\" title=\"#{build_part.paths.join(', ')}\">(#{paths})</span>".html_safe
      end
    end
  end

  def is_a_ruby_build?(build)
    build.build_parts.first.try :is_for?, :ruby
  end

  def is_a_build_with_one_part?(build)
    build.build_parts.none? {|build_part| build_part.paths.size > 1 }
  end

  def eligible_for_merge_on_success?(build)
    !build.succeeded? && !build.project.main? && build.repository.allows_kochiku_merges?
  end
end
