# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require 'webmock/rspec'
require 'nokogiri'
require 'factory_girl'
require 'capybara/rspec'
require 'git_blame'
require 'securerandom'

FIXTURE_PATH = Rails.root.join('spec', 'fixtures')

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}

module SpecHelpers
  def freeze_time!(frozen_time = Time.now)
    Time.stub(:now).and_return(frozen_time)
    frozen_time
  end
end

module RepositoryFixture
  def fixture_repo
    repo_path = Rails.root.join("tmp", SecureRandom.hex).to_s
    repo = Rugged::Repository.init_at(repo_path)
    RepositoryFixture.add_repository(repo_path)
    repo
  end

  def commit_to(repo, commiter, message)
    oid = repo.write("This is a blob. #{SecureRandom.hex}", :blob)
    builder = Rugged::Tree::Builder.new
    builder << { type: :blob, name: "README.md", oid: oid, filemode: 0100644 }

    options = {}
    options[:tree] = builder.write(repo)

    options[:author] = commiter
    options[:committer] = commiter
    options[:message] = message
    options[:parents] = repo.empty? ? [] : [ repo.head.target ].compact
    options[:update_ref] = 'HEAD'

    Rugged::Commit.create(repo, options)
  end

  def self.add_repository(path)
    @repos ||= []
    @repos << path
  end

  def self.reset_repositories
    created_repos = @repos || []
    @repos = []
    created_repos
  end
end

RSpec.configure do |config|
  config.mock_with :rspec
  config.include(SpecHelpers)
  config.include(RepositoryFixture)
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
    JobBase.stub(:enqueue_in)
    GitBlame.stub(:git_names_and_emails_since_last_green).and_return("")
    GitBlame.stub(:git_names_and_emails_in_branch).and_return("")
    GitBlame.stub(:changes_since_last_green).and_return([])
    GitBlame.stub(:changes_in_branch).and_return([])
    GitBlame.stub(:files_changed_since_last_green).and_return([])
    GitBlame.stub(:files_changed_in_branch).and_return([])

    ActionMailer::Base.deliveries.clear
  end

  config.after :each do
    RepositoryFixture.reset_repositories.each do |path|
      FileUtils.rm_rf(path)
    end
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
