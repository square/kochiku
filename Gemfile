source 'https://rubygems.org'

gem 'rails', '~> 4.1.1'
gem 'passenger', '~> 4.0.41', group: :production
gem 'dynamic_form'
gem 'rails-observers'

gem 'carrierwave'
gem 'draper', '~> 1.3', github: 'drapergem/draper', ref: 'c44894373c2ecbec41c5f3a84c83a2c21cf36aee'
gem 'mysql2'
gem 'symbolize'

gem 'haml-rails'
gem 'sass'
gem 'sass-rails', '4.0.3'  # locked for https://github.com/sstephenson/sprockets/issues/540
gem 'compass'
gem 'compass-rails'
gem 'jquery-rails'
gem 'uglifier'

# therubyracer is a JS runtime required by execjs, which is in turn required
# by uglifier. therubyracer is not the fastest option but it is the most portable.
gem 'therubyracer'

gem 'resque'
gem 'resque-scheduler'
gem 'resque-retry'
gem 'resque-web', '>= 0.0.6', require: 'resque_web'

gem 'json' # used by resque

gem 'chunky_png'
gem 'posix-spawn'  # used by cocaine
gem 'cocaine'
gem 'awesome_print', require: false
gem 'nokogiri'
gem 'httparty'

gem 'bullet'
gem 'pry-rails'
gem 'pry-byebug'

gem 'colorize', require: false

group :test, :development do
  gem 'rspec-rails', '~> 3.0.0'
  gem 'rspec-collection_matchers'
  gem 'factory_girl_rails'
end

group :development do
  gem 'capistrano', '< 3.0', require: false
  gem 'quiet_assets'
  gem 'rvm-capistrano', require: false
  gem 'thin'
  gem 'rails-erd'
end

group :test do
  gem 'webmock', require: false
  gem 'capybara', '~> 2.3'
end
