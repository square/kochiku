# source 'http://mirrors.squareup.com/rubygems'
source 'http://data01.mtv.squareup.com/rubygems'

gem 'rails', '3.2.9'
gem 'rake'
gem 'passenger', :group => :production
gem 'square-hoptoad_notifier', :require => "hoptoad_notifier"

gem 'carrierwave'
gem 'mysql2'
gem "symbolize", :require => "symbolize/active_record"

gem 'haml'
gem 'haml-rails'
gem 'sass'
gem 'compass'

gem "resque"
gem "json"                                   # used by resque
gem "system_timer", :platforms => :mri_18    # used by redis gem

gem "chunky_png"
gem "cocaine"
gem "awesome_print", :require => false
gem "nokogiri"
gem "httparty"

group :assets do
  gem 'compass-rails'
  gem 'sass-rails',   '~> 3.2.3'
  gem 'coffee-rails', '~> 3.2.1'
  gem 'uglifier', '>= 1.0.3'
end
gem 'jquery-rails'

group :development do
  #gem 'debugger', :require => false
  gem 'capistrano', :require => false
  gem 'rvm-capistrano', :require => false
end

group :test, :development do
  gem 'autotest-rails', :require => false
  gem 'autotest-fsevent', :require => false
  gem 'rspec-rails'
  gem 'factory_girl_rails'
  gem "launchy"
end

group :test do
  gem "webmock", :require => false
  gem "capybara"
end
