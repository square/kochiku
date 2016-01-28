source 'https://rubygems.org'

gem 'rails', '~> 4.2.5'
gem 'passenger', '~> 4.0.41', group: :production
gem 'dynamic_form'
gem 'rails-observers'
gem 'actionpack-action_caching'

gem 'carrierwave'
gem 'draper', '~> 2.1'
gem 'mysql2'
gem 'symbolize'

gem 'haml-rails'
gem 'sass-rails'
gem 'compass-rails'
gem 'jquery-rails'
gem 'uglifier'

# therubyracer is a JS runtime required by execjs, which is in turn required
# by uglifier. therubyracer is not the fastest option but it is the most portable.
gem 'therubyracer'
gem 'libv8', '3.16.14.7', require: false  # 3.16.14.11 has a compilation error on OSX 10.10.4

gem 'resque', '~> 1.25'
gem 'resque-scheduler', require: false
gem 'resque-retry'
gem 'resque-web', '~> 0.0.7', require: 'resque_web'
gem 'twitter-bootstrap-rails', '2.2.8' # not a direct dependency. resque-web 0.0.6 does not work with 3.X versions of this gem.

gem 'json' # used by resque

gem 'chunky_png'
gem 'posix-spawn'  # used by cocaine
gem 'cocaine'
gem 'awesome_print', require: false
gem 'nokogiri'

gem 'bullet'
gem 'pry-rails'
gem 'pry-byebug'

gem 'colorize', require: false

group :test, :development do
  gem 'rspec-rails', '~> 3.0'
  gem 'rspec-collection_matchers'
  gem 'factory_girl_rails'
end

group :development do
  gem 'capistrano', '~> 3.0', require: false
  gem 'capistrano-rails', '~> 1.1', require: false
  gem 'capistrano-bundler', '~> 1.1', require: false
  gem 'quiet_assets'
  gem 'capistrano-rvm', '~> 0.1', require: false
  gem 'thin'
  gem 'rails-erd'
  gem 'rubocop', require: false
  gem 'haml_lint', require: false
end

group :test do
  gem 'webmock', require: false
  gem 'capybara', '~> 2.3'
  gem 'fakeredis', :require => "fakeredis/rspec"
end
