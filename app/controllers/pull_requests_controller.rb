# TODO: Combine this controller with RepositoriesController#build_ref
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
      Repository.canonical_repository_url(payload['repository']['url'])
    rescue Repository::UnknownServer
      nil
    end
    repository = Repository.find_by_url(ssh_url)
    return unless repository
    project = repository.projects.where(name: repository.repository_name).first_or_create
    if payload["ref"] == "refs/heads/master" && repository.run_ci?
      sha = payload["after"]
      project.builds.create_new_build_for(sha)
    end
  end

  def handle_pull_request
    repository = Repository.find_by_url(payload['repository']['ssh_url'])
    return unless repository
    project = repository.projects.where(name: repository.repository_name + "-pull_requests").first_or_create
    if active_pull_request? && repository.build_pull_requests
      sha = payload["pull_request"]["head"]["sha"]
      branch = payload["pull_request"]["head"]["ref"]

      project.ensure_branch_build_exists(branch, sha)
    end
  end

  def active_pull_request?
    payload['action'] && payload['action'] != "closed"
  end

  def payload
    @payload ||= JSON.parse(params["payload"])
  end
end
