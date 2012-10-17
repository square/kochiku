class GithubPostReceiveHook
  SUBSCRIBE_NAME = "web"
  def initialize(repository)
    @repository = repository
    @root_uri = URI("#{repository.base_api_url}/hooks")
    @hook_uri = URI("#{repository.base_api_url}/hooks/#{repository.github_post_receive_hook_id}")
    @receive_url = Rails.application.routes.url_helpers.pull_request_build_url
    @interested_events = ['pull_request']
    @subscribe_args = {:name => "web", :config => {:url => @receive_url}, :events => @interested_events, :active => true}
  end

  def subscribe!
    if @repository.github_post_receive_hook_id
      update_repository_hook!
    else
      synchronize_or_create!
    end
  end

  private

  def update_repository_hook!
    GithubRequest.patch(@hook_uri, @subscribe_args)
  end

  def synchronize_or_create!
    response_body = GithubRequest.get(@root_uri)
    existing_hooks = JSON.parse(response_body)
    existing_subscription = existing_hooks.detect do |hook|
      hook["active"] && hook["events"] == @interested_events && hook["config"]["url"] == @receive_url
    end
    if existing_subscription
      @repository.update_attributes(:github_post_receive_hook_id => existing_subscription["id"])
      return response_body
    end
    GithubRequest.post(@root_uri, @subscribe_args)
  end
end
