class KochikuBuildCollector
  class << self
    def retrieve_all_builds(start_time, end_time)
      Build.where(created_at: start_time..end_time)
    end

    def retrieve_all_jobs(start_time, end_time)
      BuildPart.where(created_at: start_time..end_time)
    end
  end
end
