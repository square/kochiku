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

  def average_time(build_parts)
    build_parts = build_parts.reject { |build, build_part| build.is_running? }
    p build_parts.values.map(&:elapsed_time)
    # build_parts is a hash of build => build_part
    total = build_parts.inject(0) do |sum, (build, build_part)|
      sum + (build_part.elapsed_time || 0)
    end
    total.to_f / build_parts.length
  end
end
