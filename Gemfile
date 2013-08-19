source 'https://rubygems.org'

def square_gem(org, name, opts = {})
  gem name, opts.merge(git: "git@git.squareup.com:#{org}/#{name}.git")
end

gem 'rails', '3.2.14'
gem 'passenger', '4.0.10', group: :production

gem 'squash_ruby', require: 'squash/ruby'
gem 'squash_rails', require: 'squash/rails'

# TODO: this should use square_root, not guard_dog
square_gem 'square', 'guard_dog'

gem 'carrierwave'
gem 'mysql2'
gem 'symbolize'

gem 'haml-rails'
gem 'sass'
gem 'compass'

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

group :assets do
  gem 'compass-rails'
  gem 'jquery-rails'
  gem 'sass-rails'
  gem 'uglifier'
end

group :test, :development do
  gem 'rspec-rails'
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
  gem 'capybara'
end
