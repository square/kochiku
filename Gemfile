# source 'http://mirrors.squareup.com/rubygems'
source 'https://rubygems.org/'

gem 'rails', '3.0.9'

# Bundle edge Rails instead:
# gem 'rails', :git => 'git://github.com/rails/rails.git'

gem 'mysql2', '>=0.2', '<0.3'
gem "symbolize",              :git => "git@github.com:square/activerecord_symbolize.git", :ref => "8949e2d3bf2a28037397f540c3cd317c478fde16"

gem 'haml'
gem 'haml-rails'
gem 'sass'
gem 'compass'

gem "resque"
gem "resque-lock"
gem "resque-scheduler"
gem "SystemTimer"

group :development do
  gem 'ruby-debug'
end

group :test, :development do
  gem 'autotest'
  gem 'autotest-fsevent'
  gem 'rspec-rails'
end

# Bundle the extra gems:
# gem 'bj'
# gem 'nokogiri'
# gem 'sqlite3-ruby', :require => 'sqlite3'
# gem 'aws-s3', :require => 'aws/s3'

# Bundle gems for the local environment. Make sure to
# put test-only gems in this group so their generators
# and rake tasks are available in development mode:
# group :development, :test do
#   gem 'webrat'
# end
