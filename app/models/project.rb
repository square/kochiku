class Project < ActiveRecord::Base
  has_many :builds, :dependent => :destroy, :inverse_of => :project do
    def create_new_build_for(sha)
      last_build = last
      return last_build if last_build && !last_build.completed?
      build = where(ref: sha).first_or_initialize(state: :partitioning, branch: 'master')
      build.save!
      build
    end

    def find_existing_build_or_initialize(ref, initialization_values)
      existing_build = Build.joins(:project).where("projects.repository_id = ? AND builds.ref = ?", proxy_association.owner.repository_id, ref).readonly(false).first
      existing_build || build(initialization_values.merge(:ref => ref))
    end

    def for_branch(branch)
      Build.joins(:project).where("projects.repository_id = ? AND builds.branch = ?", proxy_association.owner.repository_id, branch).readonly(false).to_a
    end
  end
  belongs_to :repository

  validates_uniqueness_of :name

  def ensure_master_build_exists(sha)
    builds.create_new_build_for(sha)
  end

  def ensure_developer_build_exists(branch, sha)
    build = builds.find_existing_build_or_initialize(sha, :state  => :partitioning, :branch => branch)
    build.save!
    build
  end

  def abort_builds_for_branch(branch)
    previous_builds = builds.for_branch(branch)
    previous_builds.select{ |b| !b.completed? }.each(&:abort!)
  end

  # The fuzzy_limit is used to set a upper bound on the amount of time that the
  # sql query will take
  def build_time_history(fuzzy_limit=1000)
    result = Hash.new { |hash, key| hash[key] = [] }

    id_cutoff = builds.maximum(:id).to_i - fuzzy_limit

    execute(build_time_history_sql(id_cutoff)).each do |value|
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

  def to_param
    self.name.downcase
  end

  def main?
    self.name == repository.repository_name
  end

  def last_build_state
    builds.last.try(:state) || :unknown
  end

  def last_completed_build
    builds.completed.last
  end

  def last_build_duration
    last_completed_build.try(:elapsed_time)
  end

  private

  def execute(sql)
    self.class.connection.execute(sql)
  end

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
       WHERE builds.project_id = #{id}
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
