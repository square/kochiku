class SettingsAccessor
  def initialize(file_location)
    if !File.exist?(file_location)
      raise "config/application.yml is required to start Kochiku"
    else
      @hash = YAML.load_file(file_location).with_indifferent_access
    end
  end

  def sender_email_address
    @hash[:sender_email_address]
  end
end

Settings = SettingsAccessor.new(Rails.root.join('config', 'application.yml'))