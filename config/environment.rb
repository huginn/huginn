# Load the rails application
require File.expand_path('../application', __FILE__)

# Remove the XML parser from the list that will be used to initialize the application's XML parser list.
ActionDispatch::ParamsParser::DEFAULT_PARSERS.delete(Mime::XML)

# Initialize the rails application
Huginn::Application.initialize!
