source 'https://rubygems.org'

gem 'actionpack-action_caching', '> 1.1.1'

gem 'activemodel-serializers-xml' # required for xml serialization
gem 'rails-controller-testing' # Included to provide 'assigns' method

gem 'dynamic_form'
gem 'passenger', '~> 4.0.41', group: :production
gem 'rails', '= 5.0.6'
gem 'rails-observers'

gem 'carrierwave'
gem 'draper', '~> 3.0.1'
gem 'mysql2', '>= 0.4.4'

gem 'compass-rails'
gem 'haml-rails'
gem 'jquery-rails'
gem 'sass-rails'
gem 'uglifier'

# therubyracer is a JS runtime required by execjs, which is in turn required
# by uglifier. therubyracer is not the fastest option but it is the most portable.
gem 'therubyracer'

gem 'hiredis' # better Redis performance for usage as cache
gem 'readthis'
gem 'redis', require: ["redis", "redis/connection/hiredis"]

gem 'resque', '~> 1.27.4'
gem 'resque-retry'
gem 'resque-scheduler', require: false

gem 'json' # used by resque

gem 'awesome_print', require: false
gem 'chunky_png'
gem 'cocaine'
gem 'nokogiri', '~> 1.8', '>= 1.8.2' # 1.8.1 and below have known vulnerabilities
gem 'posix-spawn'  # used by cocaine

gem 'pry-byebug'
gem 'pry-rails'

group :test, :development do
  gem 'factory_bot_rails'
  gem 'haml_lint', require: false
  gem 'rspec-collection_matchers'
  gem 'rspec-rails', '~> 3.0'
  gem 'rubocop', require: false
end

group :development do
  gem 'bullet'
  gem 'capistrano', '~> 3.0', require: false
  gem 'capistrano-bundler', '~> 1.1', require: false
  gem 'capistrano-rails', '~> 1.1', require: false
  gem 'capistrano-rvm', '~> 0.1', require: false
  gem 'rails-erd'
  gem 'thin'
end

group :test do
  gem 'capybara', '~> 2.3'
  gem 'fakeredis', :require => "fakeredis/rspec"
  gem 'webmock', require: false
end
