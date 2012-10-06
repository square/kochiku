class PullRequestsController < ApplicationController
  def build
    project = Project.find(params[:id])
    if active_pull_request? && build_requested?
      sha = payload["pull_request"]["head"]["sha"]
      branch = payload["pull_request"]["head"]["ref"]
      build = project.builds.find_or_initialize_by_ref(sha, :state => :partitioning, :queue => :developer, :branch => branch)
      build.save!
    end
    render :json => {"message" => "Thanks!"}
  end

  protected
  def active_pull_request?
    payload['action'] && payload['action'] != "closed"
  end

  def build_requested?
    payload["pull_request"] && payload["pull_request"]["body"].to_s.downcase.include?("!buildme")
  end

  def payload
    params['payload']
  end
end
