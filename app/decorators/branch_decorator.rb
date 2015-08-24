class BranchDecorator < Draper::Decorator
  delegate_all

  def most_recent_build_state
    object.most_recent_build.try(:state) || :unknown
  end

  def last_build_duration
    object.last_completed_build.try(:elapsed_time)
  end

  # Recent build timing information grouped by test types.
  def build_time_history(fuzzy_limit=1000)
    result = Hash.new { |hash, key| hash[key] = [] }

    object.timing_data_for_recent_builds.each do |value|
      if key = value.shift  # the type of test that was executed (e.g. cucumber)
        result[key] << value
      else # unfortunate, but flot dislikes missing data
        result.keys.each do |k|
          result[k] << value
        end
      end
    end

    result
  end
end
