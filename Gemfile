source 'https://rubygems.org'

gem 'rails', '~> 4.0.2'
gem 'passenger', '~> 4.0.10', group: :production
gem 'dynamic_form'
gem 'rails-observers'

gem 'carrierwave'
gem 'draper', '~> 1.3'
gem 'mysql2'
gem 'symbolize'

gem 'haml-rails'
gem 'sass'
gem 'sass-rails'
gem 'compass'
gem 'compass-rails'
gem 'jquery-rails'
gem 'uglifier'

# therubyracer is a JS runtime required by execjs, which is in turn required
# by uglifier. therubyracer is not the fastest option but it is the most portable.
gem 'therubyracer'

gem 'resque'
gem 'resque-retry'

gem 'json' # used by resque

gem 'chunky_png'
gem 'cocaine'
gem 'awesome_print', require: false
gem 'nokogiri'
gem 'httparty'

gem 'bullet'
gem 'pry-rails'

gem 'colorize', require: false

group :test, :development do
  gem 'rspec-rails', '~> 3.0.0.beta'
  gem 'factory_girl_rails'
  gem 'launchy'
end

group :development do
  gem 'capistrano', require: false
  gem 'quiet_assets'
  gem 'rvm-capistrano', require: false
  gem 'thin'
  gem 'rails-erd'
end

group :test do
  gem 'webmock', require: false
  # Track latest capybara to silence rspec 3 deprecation
  gem 'capybara', :github => 'jnicklas/capybara'
end
