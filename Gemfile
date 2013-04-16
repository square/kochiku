source 'http://data01.mtv.squareup.com/rubygems'

gem 'rails', '3.2.13'
gem 'passenger', '3.0.18', :group => :production

gem 'squash_ruby', :require => 'squash/ruby'
gem 'squash_rails', :require => 'squash/rails'
gem 'guard_dog', :git => 'git@git.squareup.com:square/guard_dog.git'

gem 'carrierwave'
gem 'mysql2'
gem "symbolize"

gem 'haml-rails'
gem 'sass'
gem 'compass'

gem "resque"
gem "resque-retry"
gem "json"                                   # used by resque

gem "chunky_png"
gem "cocaine"
gem "awesome_print", :require => false
gem "nokogiri"
gem "httparty"

group :assets do
  gem 'coffee-rails', '~> 3.2.1'
  gem 'compass-rails'
  gem 'jquery-rails'
  gem 'sass-rails',   '~> 3.2.3'
  gem 'uglifier', '>= 1.0.3'
end

group :test, :development do
  gem 'rspec-rails'
  gem 'factory_girl_rails'
  gem "launchy"
end

group :development do
  #gem 'debugger', :require => false
  gem 'capistrano', :require => false
  gem 'quiet_assets'
  gem 'rvm-capistrano', :require => false
  gem 'thin'
end

group :test do
  gem "webmock", :require => false
  gem "capybara"
end
