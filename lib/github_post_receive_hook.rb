class GithubPostReceiveHook
  def initialize(repository)
    @uri = URI("#{repository.base_api_url}/hooks")
  end

  def subscribe!
    response_body = GithubRequest.get(@uri)
    existing_hooks = JSON.parse(response_body)
    receive_url = Rails.application.routes.url_helpers.pull_request_build_url
    already_subscribed = existing_hooks.detect do |hook|
      hook["active"] && hook["events"].include?("pull_request") && hook["config"]["url"] == receive_url
    end
    return response_body if already_subscribed
    GithubRequest.post(@uri, {:name => "web", :config => {:url => receive_url}, :events => ['pull_request'], :active => true})
  end
end
