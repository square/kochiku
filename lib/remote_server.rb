require 'remote_server/github'
require 'remote_server/stash'

module RemoteServer
  UnknownGitServer = Class.new(RuntimeError)
  UnknownUrlFormat = Class.new(RuntimeError)

  def self.for_url(url)
    server = Settings.git_server(url)

    raise UnknownGitServer, url unless server

    case server.type
      when 'stash'
        RemoteServer::Stash.new(url)
      when 'github'
        RemoteServer::Github.new(url)
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
