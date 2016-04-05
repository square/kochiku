require 'remote_server'

class PullRequestsController < ApplicationController
  def build
    if params['payload']
      # from stash
      handle_stash_request(JSON.parse(params['payload']))
    else
      # from github
      handle_github_request(params)
    end
    render json: {message: "Thanks!"}
  end

  def handle_stash_request(payload)
    @repo = get_repo(payload['repository']['url'])

    if payload['pull_request'] && active_pull_request?(payload['action'])
      branch_name = get_branch_name(payload['pull_request']['head']['ref'])
      sha = payload['pull_request']['head']['sha']
      handle_pull_request(branch_name, sha)
    elsif payload['ref']
      branch_name = get_branch_name(payload['ref'])
      sha = payload['after']
      handle_repo_push_request(branch_name, sha)
    end
  end

  def handle_github_request(payload)
    @repo = get_repo(payload['repository']['ssh_url'])

    pull_request = payload['pull_request']
    if payload['pull_request'] && active_pull_request?(pull_request['state'])
      branch_name = get_branch_name(pull_request['head']['ref'])
      sha = pull_request['head']['sha']
      handle_pull_request(branch_name, sha)
    elsif payload['ref']
      branch_name = get_branch_name(payload['ref'])
      sha = payload['head_commit']['id']
      handle_repo_push_request(branch_name, sha)
    end
  end

  private

  def get_repo(url)
    Repository.lookup_by_url(url)
  end

  def handle_repo_push_request(branch_name, sha)
    return unless @repo

    if @repo.run_ci?
      branch = fetch_branch(branch_name)
      branch.kickoff_new_build_unless_currently_busy(sha) if branch.present? && branch.convergence?
    end
  end

  def handle_pull_request(branch_name, sha)
    return unless @repo

    if @repo.build_pull_requests
      branch = fetch_branch(branch_name, true)
      build = @repo.ensure_build_exists(sha, branch)
      branch.abort_in_progress_builds_behind_build(build)
    end
  end

  def get_branch_name(ref)
    ref.sub(%r{\Arefs/heads/}, '')
  end

  def fetch_branch(name, auto_create = false)
    auto_create ? @repo.branches.where(name: name).first_or_create! : @repo.branches.where(name: name).first
  end

  def active_pull_request?(action)
    action && action != "closed"
  end
end
