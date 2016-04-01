module ProjectStatsHelper
  def pass_rate_css_class(rate)
    case rate.to_i
    when 0..39 then 'bad'
    when 40..75 then 'decent'
    else 'great'
    end
  end

  def rebuild_count_css_class(attempts)
    case attempts
    when 0..1 then 'great'
    when 1..4 then 'decent'
    else 'bad'
    end
  end

  # A string representing the percentage of builds that eventually passed
  def eventual_pass_rate(builds)
    pass_rate_text(builds.select(&:succeeded?).size / builds.size.to_f) # rubocop:disable Performance/Count
  end

  # A string representing the percentage of the builds that had
  # all tests pass on the first try.
  def error_free_pass_rate(builds)
    error_free_count = builds.to_a.count do |build|
      build.succeeded? && build.build_parts.all_passed_on_first_try?
    end
    total_count = builds.to_a.count(&:completed?)
    pass_rate_text(error_free_count / total_count.to_f)
  end

  def pass_rate_text(number)
    format("%1.0f%", 100 * number)
  end

  # Calculates the average number of rebuilds required before builds succeed.
  # Only considers builds that are successful because builds that are not yet
  # successful would skew the calculation.
  def average_number_of_rebuilds(builds)
    successful_builds = builds.select(&:succeeded?)
    total_build_parts, total_build_attempts = 0, 0

    successful_builds.each do |build|
      total_build_attempts += build.build_attempts.count
      total_build_parts += build.build_parts.count
    end

    (total_build_attempts - total_build_parts) / successful_builds.size.to_f
  end

  def median_elapsed_time(builds)
    successful_builds = builds.select(&:succeeded?)
    elapsed_times = successful_builds.map { |build| build.elapsed_time }
    times = elapsed_times.length
    if times.zero?
      nil
    else
      elapsed_times.sort!
      (elapsed_times[(times - 1) / 2] + elapsed_times[times / 2]) / 2.0
    end
  end

  def seconds_to_minutes(seconds)
    (seconds / 60).round if seconds.is_a?(Numeric)
  end
end
