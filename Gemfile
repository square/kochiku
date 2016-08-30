source 'https://rubygems.org'

gem 'rails', '~> 4.2.7'
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

gem 'redis', require: ["redis", "redis/connection/hiredis"]
gem 'hiredis' # better Redis performance for usage as cache
gem 'readthis'

gem 'resque', '~> 1.25'
gem 'resque-scheduler', require: false
gem 'resque-retry'

gem 'json' # used by resque

gem 'chunky_png'
gem 'posix-spawn'  # used by cocaine
gem 'cocaine'
gem 'awesome_print', require: false
gem 'nokogiri'

gem 'pry-rails'
gem 'pry-byebug'

group :test, :development do
  gem 'haml_lint', require: false
  gem 'rubocop', require: false
  gem 'rspec-rails', '~> 3.0'
  gem 'rspec-collection_matchers'
  gem 'factory_girl_rails'
end

group :development do
  gem 'bullet'
  gem 'capistrano', '~> 3.0', require: false
  gem 'capistrano-rails', '~> 1.1', require: false
  gem 'capistrano-bundler', '~> 1.1', require: false
  gem 'quiet_assets'
  gem 'capistrano-rvm', '~> 0.1', require: false
  gem 'thin'
  gem 'rails-erd'
end

group :test do
  gem 'webmock', require: false
  gem 'capybara', '~> 2.3'
  gem 'fakeredis', :require => "fakeredis/rspec"
end
