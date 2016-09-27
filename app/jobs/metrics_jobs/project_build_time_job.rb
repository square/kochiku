require './app/jobs/job_base'
require 'metrics_helpers/common_helper'
require 'metrics_helpers/build_stats_helper'
require 'metrics_helpers/java_builds_partitioner_helper'
require 'metrics_helpers/project_build_collector'

class ProjectBuildTimeJob < JobBase
  @queue = :low
  extend CommonHelper

  def self.perform(repo_id, start_time, end_time)
    repo = Repository.find(repo_id)
    builds = ProjectBuildCollector.retrieve_all_builds(repo_id, start_time: start_time, end_time: end_time)
    if repo.name == 'java'
      java_repo_handler(repo, builds, start_time)
    else
      jobs = ProjectBuildCollector.retrieve_all_jobs(repo_id, start_time: start_time, end_time: end_time)
      standard_repo_handler(repo, builds, jobs, start_time)
    end
  end

  def self.java_repo_handler(repo, builds, target_ts)
    JavaBuildsPartitioner.partition_builds(builds).each do |project_name, build_info|
      builds_run_time_stats = BuildStatsHelper.builds_running_time_pctl(build_info[:builds])
      jobs_wait_time_stats = BuildStatsHelper.jobs_waiting_time_pctl(build_info[:jobs])
      save_to_db(repo_id: repo.id, repo_name: repo.name, project_name: project_name, target_ts: target_ts,\
                 builds_run_time_stats: builds_run_time_stats, jobs_wait_time_stats: jobs_wait_time_stats)
    end
  end

  def self.standard_repo_handler(repo, builds, jobs, target_ts)
    jobs_wait_time_stats = BuildStatsHelper.jobs_waiting_time_pctl(jobs)
    builds_run_time_stats = BuildStatsHelper.builds_running_time_pctl(builds)
    save_to_db(repo_id: repo.id, repo_name: repo.name, project_name: repo.name, target_ts: target_ts,\
               builds_run_time_stats: builds_run_time_stats, jobs_wait_time_stats: jobs_wait_time_stats)
  end

  def self.save_to_db(data)
    record = {}
    %i(repo_id project_name repo_name).each { |key| record[key] = data[key] }
    %i(ninety_five_pctl_build_wait_time ninety_pctl_build_wait_time seventy_pctl_build_wait_time fifty_pctl_build_wait_time).each do |key|
      record[key] = data[:jobs_wait_time_stats][CommonHelper::BUILD_WAIT_TIME_PCTL_MAP[key]]
    end
    %i(ninety_five_pctl_build_run_time ninety_pctl_build_run_time seventy_pctl_pctl_build_run_time fifty_pctl_build_run_time).each do |key|
      record[key] = data[:builds_run_time_stats][CommonHelper::BUILD_RUN_TIME_PCTL_MAP[key]]
    end
    record[:target_ts] = data[:target_ts]
    record[:frequency] = 'daily'
    ProjectTimeReport.create!(record)
  end
end
