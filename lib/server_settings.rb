class ServerSettings

  attr_reader :type, :oauth_token, :stash_username, :stash_password, :mirror, :host, :aliases

  def initialize(raw_settings, host)
    @host = host
    if raw_settings
      @type = raw_settings[:type]
      @mirror = raw_settings[:mirror]
      @aliases = raw_settings[:aliases]

      # specific to Github
      if raw_settings[:oauth_token_file]
        @oauth_token = File.read(raw_settings[:oauth_token_file]).chomp
      end

      # specific to Stash
      @stash_username = raw_settings[:username]
      if raw_settings[:password_file]
        @stash_password = File.read(raw_settings[:password_file]).chomp
      end
    else
      @type = nil
      @mirror = nil
      @aliases = nil
      @oauth_token = nil
      @stash_username = nil
      @stash_password = nil
    end
  end
end
