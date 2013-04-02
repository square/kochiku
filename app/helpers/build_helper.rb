module BuildHelper
  def build_metadata_header(build)
    if is_a_ruby_build?(build)
      "Ruby Version"
    elsif is_a_build_with_one_part?(build)
      "Target"
    else
      nil
    end
  end

  def build_part_field_value(build, build_part)
    if is_a_ruby_build?(build)
      build_part.options["ruby"]
    elsif is_a_build_with_one_part?(build)
      build_part.paths.first
    end
  end

  def is_a_ruby_build?(build)
    build.build_parts.first && build.build_parts.first.is_for?(:ruby)
  end

  def is_a_build_with_one_part?(build)
    !build.build_parts.empty? && build.build_parts.all? {|build_part| build_part.paths.size == 1 }
  end

  def average_time(builds, part_index)
    builds = builds.reject(&:is_running?)

    total = builds.inject(0) do |sum, build|
      sum + (build.build_parts[part_index].try(:elapsed_time) || 0)
    end
    total.to_f / builds.length
  end
end
