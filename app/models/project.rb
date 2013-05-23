class Project < ActiveRecord::Base
  has_many :builds, :dependent => :destroy, :inverse_of => :project do
    def create_new_ci_build_for(sha)
      last_build = where(:queue => :ci).last
      return last_build if last_build && !last_build.completed?
      build = find_or_initialize_by_ref(sha, :state => :partitioning, :queue => :ci, :branch => 'master')
      build.save!
    end

    def find_existing_build_or_initialize(ref, options)
      # Always create another build for CI purposes - it would be nice to not do this but we need to link builds to achieve this.
      existing_build = Build.first(:joins => :project, :conditions => ["projects.repository_id = ? AND builds.ref = ?", proxy_association.owner.repository_id, ref], :readonly => false) unless options[:queue] == :ci
      existing_build || build(options.merge(:ref => ref))
    end
  end
  validates_uniqueness_of :name
  belongs_to :repository

  # The fuzzy_limit is used to set a upper bound on the amount of time that the
  # sql query will take
  def build_time_history(fuzzy_limit=1000)
    result = Hash.new { |hash, key| hash[key] = [] }

    id_cutoff = builds.maximum(:id).to_i - fuzzy_limit

    execute(build_time_history_sql(id_cutoff)).each do |value|
      if key = value.shift
        result[key] << value
      else # unfortunate, but flot dislikes missing data
        result.keys.each do |key|
          result[key] << value
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
