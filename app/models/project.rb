class Project < ActiveRecord::Base
  has_many :builds, :dependent => :destroy, :inverse_of => :project do
    def create_new_ci_build_for(sha)
      last_build = where(:queue => :ci).last
      return last_build if last_build && !last_build.completed?
      build = find_or_initialize_by_ref(sha, :state => :partitioning, :queue => :ci, :branch => 'master')
      build.save!
    end
  end
  validates_uniqueness_of :name
  belongs_to :repository

  # The fuzzy_limit is used to set a upper bound on the amount of time that the
  # sql query will take
  def build_time_history(fuzzy_limit=1000)
    result = Hash.new { |hash, key| hash[key] = [] }

    result['max'] = builds.order(:id).last.try(:id).to_i
    id_cutoff = result['max'] - fuzzy_limit
    result['min'] = builds.order(:id).where("id >= #{id_cutoff}").first.try(:id).to_i

    execute(build_time_history_sql(id_cutoff)).each do |value|
      result[value.shift] << value
    end


    result
  end

  def to_param
    self.name.downcase
  end

  def main_build?
    self.name == repository.repository_name
  end

  private

  def execute(sql)
    self.class.connection.execute(sql)
  end

  def build_time_history_sql(min_build_id)
    return <<-SQL
      SELECT build_parts.kind,
             builds.id,
             FLOOR(ROUND(MAX(UNIX_TIMESTAMP(build_attempts.finished_at) - UNIX_TIMESTAMP(build_attempts.started_at)) / 60)),
             FLOOR(ROUND(MIN(UNIX_TIMESTAMP(build_attempts.finished_at) - UNIX_TIMESTAMP(build_attempts.started_at)) / 60))
        FROM builds
        JOIN build_parts ON build_parts.build_id = builds.id
        JOIN build_attempts ON build_attempts.build_part_id = build_parts.id
       WHERE builds.project_id = #{id}
         AND builds.id >= #{min_build_id}
         AND builds.state IN ('succeeded', 'failed')
         AND build_attempts.id = (
               SELECT id
                 FROM build_attempts
                WHERE build_part_id = build_parts.id
                  AND state IN ('passed', 'failed')
             ORDER BY id DESC
                LIMIT 1
             )
    GROUP BY builds.id, build_parts.kind
    SQL
  end
end
