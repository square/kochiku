require 'github_request'

class GithubCommitStatus
  def initialize(build, oauth_token)
    @oauth_token = oauth_token
    @url = "#{build.repository.base_api_url}/statuses/#{build.ref}"
    @build = build
    @build_url = Rails.application.routes.url_helpers.repository_build_url(build.repository, build)
  end

  def update_commit_status!
    if @build.succeeded?
      mark_as("success", "Build passed!")
    elsif @build.failed? || @build.aborted?
      mark_as("failure", "Build failed")
    else
      mark_as("pending", "Build is running")
    end
  end

  private

  def mark_as(state, description)
    GithubRequest.post(@url, {:state => state, :target_url => @build_url, :description => description}, @oauth_token)
  end
end
