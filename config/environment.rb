# Load the rails application
require File.expand_path('../application', __FILE__)

# Load application settings for Kochiku
require File.expand_path('../../lib/settings_accessor', __FILE__)

CONF_FILE =
  if Rails.env.test?
    File.expand_path('../application.test.yml', __FILE__)
  elsif Rails.env.development?
    File.expand_path('../application.dev.yml', __FILE__)
  else
    File.expand_path('../application.yml', __FILE__)
  end

raise("#{CONF_FILE} is required to start Kochiku") unless File.exist?(CONF_FILE)

Settings = SettingsAccessor.new(File.read(CONF_FILE))

# Disable symbol and yaml parsing in the XML parser to avoid
# other code paths being exploited.
# https://www.ruby-forum.com/attachment/8029/cve-2013-0156-poc.txt
ActiveSupport::XmlMini::PARSING.delete("symbol")
ActiveSupport::XmlMini::PARSING.delete("yaml")

# Initialize the rails application
Kochiku::Application.initialize!
