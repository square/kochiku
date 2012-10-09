class GithubCommitStatus
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
    GithubRequest.post(@uri, {:state => state, :target_url => @build_url, :description => description})
  end
end
