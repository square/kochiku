require 'uri'
require 'net/http'

class GithubCommitStatus
  OAUTH_TOKEN = "39408724f3a92bd017caa212cc7cf2bbb5ac02b6"

  def initialize(build)
    # TODO: this should dynamically point to a github server
    @uri = URI("https://git.squareup.com/api/v3/repos/square/web/statuses/#{build.ref}")
    @build_url = Rails.application.routes.url_helpers.project_build_url(build.project, build)
  end

  def pending!
    mark_as("pending", "Build is running")
  end

  def success!
    mark_as("success", "Build passed!")
  end

  def failure!
    mark_as("failure", "Build failed")
  end

  def error!
    mark_as("error", "Build errored out")
  end

  private
  def mark_as(state, description)
    Net::HTTP.start(@uri.host, @uri.port, :use_ssl => @uri.scheme == 'https') do |http|
      response = http.post(@uri.path, {:state => state, :target_url => @build_url, :description => description}.to_json, {"Authorization" => "token #{OAUTH_TOKEN}"})
      Rails.logger.info("Github commit status response: " + response.inspect)
    end
  end
end
