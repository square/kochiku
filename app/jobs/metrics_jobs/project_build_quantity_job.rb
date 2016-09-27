require './app/jobs/job_base'
require 'metrics_helpers/project_build_collector'
require 'metrics_helpers/java_builds_partitioner_helper'

class ProjectBuildQuantityJob < JobBase
  @queue = :low

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
    unless builds.blank?
      JavaBuildsPartitioner.partition_builds(builds).each do |project_name, build_info|
        save_to_db(repo_id: repo.id, project_name: project_name, repo_name: repo.name, target_ts: target_ts,\
                   build_number: build_info[:builds].count, job_number: build_info[:jobs].count)
      end
    end
  end

  def self.standard_repo_handler(repo, builds, jobs, target_ts)
    save_to_db(repo_id: repo.id, project_name: repo.name, repo_name: repo.name, target_ts: target_ts,\
               build_number: builds.count, job_number: jobs.count)
  end

  def self.save_to_db(data)
    record = {}
    %i(repo_id project_name repo_name build_number job_number).each { |key| record[key] = data[key] }
    record[:target_ts] = data[:target_ts]
    record[:frequency] = 'daily'
    ProjectQuantityReport.create!(record)
  end
end
