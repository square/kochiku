# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require 'webmock/rspec'
require 'nokogiri'
require 'factory_girl'
require 'capybara/rspec'
require 'git_blame'

FIXTURE_PATH = Rails.root.join('spec', 'fixtures')

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}


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

  config.before :each do
    WebMock.disable_net_connect!
    allow(JobBase).to receive(:enqueue_in)

    allow(GitBlame).to receive(:git_names_and_emails_since_last_green).and_return("")
    allow(GitBlame).to receive(:git_names_and_emails_in_branch).and_return("")
    allow(GitBlame).to receive(:changes_since_last_green).and_return([])
    allow(GitBlame).to receive(:changes_in_branch).and_return([])
    allow(GitBlame).to receive(:files_changed_since_last_green).and_return([])
    allow(GitBlame).to receive(:files_changed_in_branch).and_return([])

    ActionMailer::Base.deliveries.clear
  end

  config.before(:suite) do
    test_repo = Rails.root.join('tmp', 'build-partition', 'test-repo-cache')
    unless File.exist?(test_repo)
      FileUtils.mkdir_p test_repo
      Dir.chdir(test_repo) do
        Cocaine::CommandLine.new("git init").run
      end
    end
  end
end
