# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require 'webmock/rspec'
require 'nokogiri'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}

FIXTURE_PATH = Rails.root.join('spec', 'fixtures')

RSpec.configure do |config|
  config.mock_with :rspec

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = FIXTURE_PATH

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # Define which fixtures should be globally available. Set to :all to load everything
  # config.global_fixtures = :all
  config.global_fixtures = :projects

  config.before :each do
    WebMock.disable_net_connect!
    Resque.stub(:enqueue)    
    JobBase.stub(:enqueue_in)
  end
end
