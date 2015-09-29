require 'remote_server'

# This controller receives webhooks from Github only. Stash webhooks are
# received by RepositoriesController#build_ref. At some point we should
# consolidate the two actions into a single controller.
class PullRequestsController < ApplicationController

  # TODO(rob): pretty good chance Github's request format has changed and this action won't work anymore. Verify.
  def build
    if payload['host']
      @repository = Repository.lookup(host: payload["host"], namespace: payload["repository"]["key"], name:payload["repository"]["slug"])
    else
      url = payload['repository']['url'] || payload['repository']['ssh_url']
      ssh_url = RemoteServer.for_url(url).canonical_repository_url
      @repository = Repository.lookup_by_url(ssh_url)
    end

    handle_pull_request if payload["pull_request"]
    handle_repo_push_request if payload["ref"]
    render :json => {:message => "Thanks!"}
  end

  protected

  # New commits have been pushed to the repo. Check if the push was to the
  # master branch and if so, kick of a new build.
  def handle_repo_push_request
    return unless @repository

    branch_name = payload["ref"].sub(%r{\Arefs/heads/}, '')
    branch = @repository.branches.where(name: branch_name).first
    if branch.present? && branch.convergence? && @repository.run_ci?
      sha = payload["after"]
      branch.kickoff_new_build_unless_currently_busy(sha)
    end
  end

  def handle_pull_request
     return unless @repository

    if active_pull_request? && @repository.build_pull_requests
      sha = payload["pull_request"]["head"]["sha"]
      branch_name = payload["pull_request"]["head"]["ref"].sub(%r{\Arefs/heads/}, '')
      branch = @repository.branches.where(name: branch_name).first_or_create!

      build = @repository.ensure_build_exists(sha, branch)
      branch.abort_in_progress_builds_behind_build(build)
    end
  end

  def active_pull_request?
    payload['action'] && payload['action'] != "closed"
  end

  def payload
    @payload ||= JSON.parse params["payload"]
  end
end
