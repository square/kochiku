module PassRateHelper

  def pass_rate_css_class(rate)
    if rate.to_i > 95
      'high'
    elsif rate.to_i > 80
      'medium'
    else
      'low'
    end
  end

  # A string representing the percentage of builds that eventually passed
  def eventual_pass_rate(builds)
    pass_rate_text(builds.select(&:succeeded?).size / builds.size.to_f)
  end

  # A string representing the percentage of the builds that had
  # all tests pass on the first try.
  def error_free_pass_rate(builds)
    error_free_count = builds.count do |build|
      build.succeeded? && build.build_parts.all_passed_on_first_try?
    end
    pass_rate_text(error_free_count / builds.size.to_f)
  end

  def pass_rate_text(number)
    "%1.0f" % (100 * number) + "%"
  end
end
