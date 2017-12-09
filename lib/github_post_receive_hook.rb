# frozen_string_literal: true
require 'github_request'

class GithubPostReceiveHook
  SUBSCRIBE_NAME = "web"

  def initialize(repository, oauth_token)
    @repository = repository
    @oauth_token = oauth_token
    @root_url = "#{repository.base_api_url}/hooks"
    @hook_url = "#{repository.base_api_url}/hooks/#{repository.github_post_receive_hook_id}"
    @receive_url = Rails.application.routes.url_helpers.pull_request_build_url
    @interested_events = @repository.interested_github_events
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
    begin
      GithubRequest.patch(@hook_url, @subscribe_args, @oauth_token)
    rescue GithubRequest::ResponseError => e
      if e.response.class == Net::HTTPNotFound
        create_hook
      else
        raise e
      end
    end
  end

  def synchronize_or_create!
    begin
      response_body = GithubRequest.get(@root_url, @oauth_token)
      existing_hooks = JSON.parse(response_body)
      existing_subscription = existing_hooks.detect do |hook|
        hook["active"] && hook["events"] == @interested_events && hook["config"]["url"] == @receive_url
      end
      if existing_subscription
        @repository.update_attributes(:github_post_receive_hook_id => existing_subscription["id"])
        return response_body
      end
    rescue GithubRequest::ResponseError
      Rails.logger.info("Failed to get hooks for #{@root_url}")
    end

    create_hook
  end

  def create_hook
    GithubRequest.post(@root_url, @subscribe_args, @oauth_token)
  end
end
