class ProjectQuantityReport < ActiveRecord::Base
  validates :project_name, uniqueness: { scope: [:target_ts, :frequency] }
end
