class ServerSettings

  attr_reader :type, :username, :mirror, :host

  def initialize(raw_settings, host)
    @host = host
    if raw_settings
      @type = raw_settings[:type]
      @username = raw_settings[:username]
      @raw_password_file = raw_settings[:password_file]
      @mirror = raw_settings[:mirror]
    else
      @type = nil
      @username = nil
      @raw_password_file = nil
      @mirror = nil
    end
  end

  def password_file
    file = Pathname.new(@raw_password_file)
    if file.relative?
      File.join(File.expand_path('../..', __FILE__), file)
    else
      file
    end.to_s
  end
end