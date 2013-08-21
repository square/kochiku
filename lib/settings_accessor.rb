class SettingsAccessor
  def initialize(file_location)
    if !File.exist?(file_location)
      raise "#{file_location} is required to start Kochiku"
    else
      @hash = YAML.load_file(file_location).with_indifferent_access
    end
  end

  def sender_email_address
    @hash[:sender_email_address]
  end

  def kochiku_notifications_email_address
    @hash[:kochiku_notifications_email_address]
  end

  def domain_name
    @hash[:domain_name]
  end

  def kochiku_protocol
    @hash[:use_https] == 'true' ? "https" : "http"
  end

  def kochiku_host
    @hash[:kochiku_host]
  end

  def kochiku_host_with_protocol
    "#{kochiku_protocol}://#{kochiku_host}"
  end

  def git_mirror
    @hash[:git_mirror]
  end
end
