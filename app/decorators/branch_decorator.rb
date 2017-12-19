require 'set'

class BranchDecorator < Draper::Decorator
  delegate_all

  def most_recent_build_state
    object.most_recent_build.try(:state) || :unknown
  end

  def last_build_duration
    object.last_completed_build.try(:elapsed_time)
  end

  # Recent build timing information grouped by test types.
  def build_time_history(fuzzy_limit = 1000)
    result = Hash.new { |hash, key| hash[key] = [] }

    builds = {}
    build_types = Set.new
    object.timing_data_for_recent_builds.each do |timing_data|
      next if timing_data.empty?
      build_type = timing_data.shift # the type of test that was executed (e.g. cucumber)
      build_id = timing_data[4] # e.g 65874
      build_types.add(build_type)
      builds[build_id] ||= {}
      builds[build_id][build_type] = timing_data
    end

    builds.keys.sort.each do |build|
      build_types.each do |build_type|
        timing_data = builds[build][build_type] || [] # jquery.flot dislikes missing data
        result[build_type] << timing_data
      end
    end

    result
  end
end
