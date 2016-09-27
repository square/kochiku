class JavaBuildsPartitioner
  def self.partition_builds(builds)
    ret = {}
    project_map = builds.first.deployable_map

    # eager loading
    Build.includes(:build_parts).where(id: builds.map(&:id)).each do |build|
      build.build_parts.each do |job|
        job.paths.each do |path|
          next unless project_map[path].present?
          project_name = project_map[path]
          ret[project_name] = { builds: [], jobs: [] } unless ret[project_name]
          ret[project_name][:jobs] << job
          ret[project_name][:builds] << build if ret[project_name][:builds].empty? || ret[project_name][:builds].last.id != build.id
        end
      end
    end
    ret
  end
end
