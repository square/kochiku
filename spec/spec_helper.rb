# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require 'rspec/collection_matchers'
require 'webmock/rspec'
require 'nokogiri'
require 'factory_girl'
require 'capybara/rspec'
require 'git_blame'

FIXTURE_PATH = Rails.root.join('spec', 'fixtures')

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}

# Checks for pending migrations before tests are run.
ActiveRecord::Migration.maintain_test_schema!

# Test decorators independent of ActionController
# https://github.com/drapergem/draper#isolated-tests
Draper::ViewContext.test_strategy :fast

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.mock_with :rspec do |mocks|
    # Cause any verifying double instantiation for a class that does not
    # exist to raise, protecting against incorrectly spelt names.
    mocks.verify_doubled_constant_names = true
  end

  config.fixture_path = FIXTURE_PATH

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # Define which fixtures should be globally available. Set to :all to load everything
  # config.global_fixtures = :all

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  config.infer_spec_type_from_file_location!

  # lil speed increase because we are not spawning threads in our tests
  config.threadsafe = false

  config.before :each do
    WebMock.disable_net_connect!
    allow(JobBase).to receive(:enqueue_in)

    allow(GitBlame).to receive(:git_names_and_emails_since_last_green).and_return("")
    allow(GitBlame).to receive(:git_names_and_emails_in_branch).and_return("")
    allow(GitBlame).to receive(:changes_since_last_green).and_return([])
    allow(GitBlame).to receive(:changes_in_branch).and_return([])
    allow(GitBlame).to receive(:files_changed_since_last_build).and_return([])
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
