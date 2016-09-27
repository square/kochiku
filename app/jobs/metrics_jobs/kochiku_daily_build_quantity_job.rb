require './app/jobs/job_base'
require 'metrics_helpers/kochiku_build_collector'

class KochikuDailyBuildQuantityJob < JobBase
  @queue = :low

  def self.perform
    target_date_beginning = (Time.current - 1.day).beginning_of_day
    target_date_end = target_date_beginning.end_of_day
    record = {}
    record[:build_number] = KochikuBuildCollector.retrieve_all_builds(target_date_beginning, target_date_end).count
    record[:job_number] = KochikuBuildCollector.retrieve_all_jobs(target_date_beginning, target_date_end).count
    record[:target_ts] = target_date_beginning
    record[:frequency] = :daily
    KochikuQuantityReport.create!(record)
  end
end
