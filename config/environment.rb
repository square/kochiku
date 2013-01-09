# Load the rails application
require File.expand_path('../application', __FILE__)

# Disable the default XML params parser - its full of holes
# See https://go.squareup.com/jira/browse/VULN-68
ActionDispatch::ParamsParser::DEFAULT_PARSERS.delete(Mime::XML)

# Disable symbol and yaml parsing in the XML parser to avoid
# other code paths being exploited.
# See https://go.squareup.com/jira/browse/VULN-74
ActiveSupport::XmlMini::PARSING.delete("symbol")
ActiveSupport::XmlMini::PARSING.delete("yaml")

# Initialize the rails application
Kochiku::Application.initialize!
