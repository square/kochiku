class PullRequestsController < ApplicationController
  def build
    project = Project.find(params[:id])
    payload = params['payload']
    Rails.logger.error("GITHUB pull request")
    Rails.logger.error(payload)
    Rails.logger.error("GITHUB pull request")
    render :json => {"message" => "Thanks!"}
  end
end