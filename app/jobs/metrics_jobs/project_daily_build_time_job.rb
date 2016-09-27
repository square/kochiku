class ProjectDailyBuildTimeJob < JobBase
  @queue = :high

  TS_START = Time.current.yesterday.beginning_of_day
  TS_END = TS_START.end_of_day

  def self.perform
    Repository.all.each { |repo|  Resque.enqueue_to("low", "ProjectBuildTimeJob", repo.id, TS_START, TS_END) }
  end
end
