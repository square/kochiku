class BuildStatsHelper
  class << self
    def jobs_waiting_time_pctl(jobs)
      ret = { '0.95' => 0, '0.9' => 0, '0.7' => 0, '0.5' => 0 }
      # eager loading
      valid_jobs = BuildPart.includes(:build_attempts).where(id: jobs.map(&:id)).select { |job| job.started_at.present? }
      if valid_jobs.present?
        sorted_wait_times = valid_jobs.map { |job| (job.started_at - job.created_at).ceil }.sort
        ret.keys.each { |p| ret[p] = sorted_wait_times[(sorted_wait_times.size * p.to_f).to_i] }
      end
      ret
    end

    def builds_running_time_pctl(builds)
      ret = { '0.95' => 0, '0.9' => 0, '0.7' => 0, '0.5' => 0 }
      valid_builds = Build.includes(:build_parts, :build_attempts).where(id: builds.map(&:id)).select { |build| build.state == :succeeded }
      if valid_builds.present?
        sorted_builds = valid_builds.map(&:linear_time).sort
        ret.keys.each { |p| ret[p] = sorted_builds[((sorted_builds.size - 1) * p.to_f).to_i] }
      end
      ret
    end
  end
end
