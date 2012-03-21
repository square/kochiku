# source 'http://mirrors.squareup.com/rubygems'
source 'https://rubygems.org/'

gem 'rails', '3.2.2'
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

gem "rest-client", :require => false
gem "cocaine"
gem "awesome_print", :require => false

group :development do
  # ruby-debug19 for 1.9.3 is still considered unstable. Reenable this once
  # linecache19-0.5.13 and ruby-debug-base19-0.11.26 have been released
  #gem 'ruby-debug19', :require => 'ruby-debug', :platforms => :mri_19

  gem 'capistrano', :require => false
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
  gem "nokogiri", :require => false
  gem "capybara"
end
