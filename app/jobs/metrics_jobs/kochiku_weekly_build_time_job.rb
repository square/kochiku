require './app/jobs/job_base'
require 'metrics_helpers/kochiku_build_collector'
require 'metrics_helpers/build_stats_helper'

class KochikuWeeklyBuildTimeJob < JobBase
  @queue = :low

  def self.perform
    end_of_last_week = (Time.current - 1.day).end_of_week
    beginning_of_last_week = end_of_last_week.beginning_of_week

    all_jobs = KochikuBuildCollector.retrieve_all_jobs(beginning_of_last_week, end_of_last_week)

    pctl_stats = BuildStatsHelper.jobs_waiting_time_pctl(all_jobs)
    record = {}
    record[:ninety_five_pctl_job_wait_time] = pctl_stats['0.95']
    record[:ninety_pctl_job_wait_time] = pctl_stats['0.9']
    record[:seventy_pctl_job_wait_time] = pctl_stats['0.7']
    record[:fifty_pctl_job_wait_time] = pctl_stats['0.5']
    record[:target_ts] = beginning_of_last_week
    record[:frequency] = :weekly
    KochikuTimeReport.create!(record)
  end
end
