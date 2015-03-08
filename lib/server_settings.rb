class ServerSettings

  attr_reader :type, :oauth_token, :username, :password_file, :mirror, :host, :aliases

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
      @username = raw_settings[:username]
      @password_file = raw_settings[:password_file]
    else
      @type = nil
      @mirror = nil
      @aliases = nil
      @oauth_token = nil
      @username = nil
      @password_file = nil
    end
  end
end
