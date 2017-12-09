class Branch < ActiveRecord::Base
  belongs_to :repository
  has_many :builds, :dependent => :destroy, :inverse_of => :branch_record

  validates :name, :presence => true

  def to_param
    self.name
  end

  def kickoff_new_build_unless_currently_busy(ref)
    last_build = builds.last
    if last_build && !last_build.completed?
      last_build
    else
      builds.create_with(state: :partitioning).find_or_create_by!(ref: ref)
    end
  end

  def abort_in_progress_builds_behind_build(current_build)
    builds.where(state: Build::IN_PROGRESS_STATES).readonly(false)
          .reject { |build| build.id >= current_build.id }
          .each { |build| build.abort! }
  end

  def most_recent_build
    @most_recent_build ||= builds.last
  end

  def last_completed_build
    @last_completed_build ||= builds.completed.last
  end

  # The fuzzy_limit is used to set a upper bound on the amount of time that the
  # sql query will take
  def timing_data_for_recent_builds(fuzzy_limit = 1000)
    id_cutoff = builds.maximum(:id).to_i - fuzzy_limit

    self.class.connection.execute(build_time_history_sql(id_cutoff))
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
       WHERE builds.branch_id = #{id}
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
