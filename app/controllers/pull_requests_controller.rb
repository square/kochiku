# TODO: This controller is Github specific. Rename accordingly. See
# RepositoriesController#build_ref for a standard way.
class PullRequestsController < ApplicationController
  skip_before_filter :verify_authenticity_token, :only => [:build]

  def build
    handle_pull_request if payload["pull_request"]
    handle_repo_push_request if payload["ref"]
    render :json => {"message" => "Thanks!"}
  end

  protected

  def handle_repo_push_request
    ssh_url = begin
      Repository.convert_to_ssh_url(payload['repository']['url'])
    rescue Repository::UnknownServer
      nil
    end
    repository = Repository.find_by_url(ssh_url)
    return unless repository
    project = repository.projects.find_or_create_by_name(repository.repository_name)
    if payload["ref"] == "refs/heads/master" && repository.run_ci?
      sha = payload["after"]
      project.builds.create_new_ci_build_for(sha)
    end
  end

  def handle_pull_request
    repository = Repository.find_by_url(payload['repository']['ssh_url'])
    project = repository.projects.find_or_create_by_name(repository.repository_name + "-pull_requests")
    if active_pull_request? && (build_requested_for_pull_request? || repository.build_pull_requests)
      sha = payload["pull_request"]["head"]["sha"]
      branch = payload["pull_request"]["head"]["ref"]
      build = project.builds.find_existing_build_or_initialize(sha, :state => :partitioning, :queue => :developer, :branch => branch)
      build.save!
    end
  end

  def active_pull_request?
    payload['action'] && payload['action'] != "closed"
  end

  def build_requested_for_pull_request?
    payload["pull_request"] && payload["pull_request"]["body"].to_s.downcase.include?("!buildme")
  end

  def payload
    @payload ||= JSON.parse(params["payload"])
  end
end
