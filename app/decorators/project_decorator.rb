class ProjectDecorator < Draper::Decorator
  delegate_all

  def most_recent_build
    @most_recent_build ||= object.builds.last
  end

  def most_recent_build_state
    most_recent_build.try(:state) || :unknown
  end

  def last_completed_build
    @last_completed_build ||= object.builds.completed.last
  end

  def last_build_duration
    last_completed_build.try(:elapsed_time)
  end

  # The fuzzy_limit is used to set a upper bound on the amount of time that the
  # sql query will take
  def build_time_history(fuzzy_limit=1000)
    result = Hash.new { |hash, key| hash[key] = [] }

    id_cutoff = builds.maximum(:id).to_i - fuzzy_limit

    object.class.connection.execute(build_time_history_sql(id_cutoff)).each do |value|
      if key = value.shift
        result[key] << value
      else # unfortunate, but flot dislikes missing data
        result.keys.each do |k|
          result[k] << value
        end
      end
    end

    result
  end

  private

  def build_time_history_sql(min_build_id)
    return <<-SQL
      SELECT build_parts.kind AS kind,
             SUBSTR(builds.ref, 1, 5) AS ref,
             IFNULL(FLOOR(ROUND(MAX(UNIX_TIMESTAMP(build_attempts.finished_at) - UNIX_TIMESTAMP(build_attempts.started_at)) / 60)), 0) AS max,
             IFNULL(FLOOR(ROUND(MAX(UNIX_TIMESTAMP(build_attempts.finished_at) - UNIX_TIMESTAMP(build_attempts.started_at)) / 60)) - FLOOR(ROUND(MIN(UNIX_TIMESTAMP(build_attempts.finished_at) - UNIX_TIMESTAMP(build_attempts.started_at)) / 60)), 0) AS min_diff,
             0 AS max_diff,
             builds.id,
             builds.state,
             builds.created_at
        FROM builds
   LEFT JOIN build_parts ON build_parts.build_id = builds.id
   LEFT JOIN build_attempts ON build_attempts.build_part_id = build_parts.id
       WHERE builds.project_id = #{object.id}
         AND builds.id >= #{min_build_id}
         AND (build_attempts.id IS NULL OR build_attempts.id = (
               SELECT id
                 FROM build_attempts
                WHERE build_part_id = build_parts.id
             ORDER BY id DESC
                LIMIT 1
             ))
    GROUP BY builds.id, build_parts.kind, builds.state, builds.created_at
    SQL
  end
end
