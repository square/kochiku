require 'uri'
require 'net/http'

class GithubCommitStatus
  OAUTH_TOKEN = "39408724f3a92bd017caa212cc7cf2bbb5ac02b6"

  def initialize(build)
    @uri = URI("#{build.repository.base_api_url}/statuses/#{build.ref}")
    @build = build
    @build_url = Rails.application.routes.url_helpers.project_build_url(build.project, build)
  end

  def update_commit_status!
    if @build.succeeded?
      mark_as("success", "Build passed!")
    elsif @build.failed?
      mark_as("failure", "Build failed")
    else
      mark_as("pending", "Build is running")
    end
  end

  private
  def mark_as(state, description)
    Net::HTTP.start(@uri.host, @uri.port, :use_ssl => @uri.scheme == 'https') do |http|
      response = http.post(@uri.path, {:state => state, :target_url => @build_url, :description => description}.to_json, {"Authorization" => "token #{OAUTH_TOKEN}"})
      Rails.logger.info("Github commit status response: " + response.inspect)
    end
  end
end
