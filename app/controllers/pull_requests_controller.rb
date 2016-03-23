require 'remote_server'

# This controller receives webhooks from Github only. Stash webhooks are
# received by RepositoriesController#build_ref. At some point we should
# consolidate the two actions into a single controller.
class PullRequestsController < ApplicationController

  # TODO(rob): pretty good chance Github's request format has changed and this action won't work anymore. Verify.
  def build
    @repository = Repository.lookup(host: "github.com", namespace: repo_namespace, name: repo["name"])
    unless @repository
      raw_url = repo["html_url"] || repo["ssh_url"]
      ssh_url = RemoteServer.for_url(raw_url).canonical_repository_url
      @repository = Repository.lookup_by_url(ssh_url)
    end

    handle_pull_request if pull_request_event?
    handle_repo_push_request if push_event?
    render :json => {:message => "Thanks!"}
  end

  protected

  # New commits have been pushed to the repo. Check if the push was to the
  # master branch and if so, kick of a new build.
  def handle_repo_push_request
    return unless @repository

    branch_name = fetch_branch_name(params["ref"])
    branch = @repository.branches.where(name: branch_name).first
    if branch.present? && branch.convergence? && @repository.run_ci?
      head_sha = params["after"]
      branch.kickoff_new_build_unless_currently_busy(head_sha)
    end
  end

  def handle_pull_request
    return unless @repository

    if active_pull_request? && @repository.build_pull_requests
      head_sha = pull_request["head"]["sha"]
      branch_name = fetch_branch_name(pull_request["head"]["ref"])
      branch = @repository.branches.where(name: branch_name).first_or_create!
      build = @repository.ensure_build_exists(head_sha, branch)
      branch.abort_in_progress_builds_behind_build(build)
    end
  end

  # "refs/heads/master" => "master"
  def fetch_branch_name(ref)
    ref.sub(%r{\Arefs/heads/}, '')
  end

  def active_pull_request?
    pull_request["state"] && pull_request["state"] != "closed"
  end

  def pull_request_event?
    params["pull_request"].present?
  end

  def push_event?
    params["ref"].present?
  end

  def repo_namespace
    repo["full_name"].split("/").first if repo["full_name"].present?
  end

  def pull_request
    params["pull_request"]
  end

  def repo
    params["repository"]
  end
end
