class PullRequestsController < ApplicationController
  skip_before_filter :verify_authenticity_token, :only => [:build]

  def build
    repository = Repository.find_by_url(payload['repository']['ssh_url'])
    handle_pull_request if payload["pull_request"]
    render :json => {"message" => "Thanks!"}
  end

  protected

  def handle_pull_request
    project = repository.projects.find_or_create_by_name(repository.repository_name + "-pull_requests")
    if active_pull_request? && (build_requested_for_pull_request? || repository.build_pull_requests)
      sha = payload["pull_request"]["head"]["sha"]
      branch = payload["pull_request"]["head"]["ref"]
      build = project.builds.find_or_initialize_by_ref(sha, :state => :partitioning, :queue => :developer, :branch => branch)
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
