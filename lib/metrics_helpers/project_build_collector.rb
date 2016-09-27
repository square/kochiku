require 'metrics_helpers/common_helper'

class ProjectBuildCollector
  extend CommonHelper
  class << self
    def retrieve_all_jobs(project_id, options={})
      builds = retrieve_all_builds(project_id, options)
      BuildPart.where(build_id: builds.pluck(:id))
    end

    def retrieve_all_builds(project_id, options={})
      time_range = filter_time_range(options)
      Build.joins(:branch_record).where(builds: { created_at: time_range }, branches: { repository_id: project_id })
    end
  end
end
