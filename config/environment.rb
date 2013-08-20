# Load the rails application
require File.expand_path('../application', __FILE__)

# Disable the default XML params parser - we aren't using it and in the past
# it has had security holes such as CVE-2013-0156
ActionDispatch::ParamsParser::DEFAULT_PARSERS.delete(Mime::XML)

# Disable symbol and yaml parsing in the XML parser to avoid
# other code paths being exploited.
# https://www.ruby-forum.com/attachment/8029/cve-2013-0156-poc.txt
ActiveSupport::XmlMini::PARSING.delete("symbol")
ActiveSupport::XmlMini::PARSING.delete("yaml")

# Initialize the rails application
Kochiku::Application.initialize!
