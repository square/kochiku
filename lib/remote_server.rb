require 'remote_server/github'
require 'remote_server/stash'

module RemoteServer
  UnknownGitServer = Class.new(RuntimeError)
  UnknownUrlFormat = Class.new(RuntimeError)
  RefDoesNotExist = Class.new(RuntimeError)
  class AccessDenied < StandardError
    def initialize(url, action, original_message = nil)
      @url = url
      @action = action
      @original_message = original_message
    end

    def to_s
      "Authorization failure when attempting to call #{@url} via #{@action}"
    end
  end

  def self.for_url(url)
    server = Settings.git_server(url)

    raise UnknownGitServer, url unless server

    case server.type
    when 'stash'
      RemoteServer::Stash.new(url, server)
    when 'github'
      RemoteServer::Github.new(url, server)
    else
      raise UnknownGitServer, "No implementation for server type #{type}"
    end
  end

  def self.parseable_url?(url)
    (RemoteServer::Stash::URL_PARSERS + RemoteServer::Github::URL_PARSERS).any? do |format|
      url =~ format
    end
  end
end
