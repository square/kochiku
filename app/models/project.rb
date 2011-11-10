class Project < ActiveRecord::Base
  has_many :builds, :dependent => :destroy, :inverse_of => :project
  validates_uniqueness_of :name

  def build_time_history
    result = Hash.new { |hash, key| hash[key] = [] }

    execute(build_time_history_sql).each do |value|
      result[value.shift] << value
    end

    result['min'] = builds.order(:id).first.try(:id).to_i
    result['max'] = builds.order(:id).last.try(:id).to_i

    result
  end

  def to_param
    self.name.downcase
  end

  private

  def execute(sql)
    self.class.connection.execute(sql)
  end

  def build_time_history_sql
    return <<-SQL
      SELECT build_parts.kind,
             builds.id,
             FLOOR(ROUND(MAX(UNIX_TIMESTAMP(build_attempts.finished_at) - UNIX_TIMESTAMP(build_attempts.started_at)) / 60)),
             FLOOR(ROUND(MIN(UNIX_TIMESTAMP(build_attempts.finished_at) - UNIX_TIMESTAMP(build_attempts.started_at)) / 60))
        FROM builds
        JOIN build_parts ON build_parts.build_id = builds.id
        JOIN build_attempts ON build_attempts.build_part_id = build_parts.id
       WHERE builds.project_id = #{id}
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
