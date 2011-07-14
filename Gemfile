# source 'http://mirrors.squareup.com/rubygems'
source 'https://rubygems.org/'

gem 'rails', '3.0.9'
gem 'thin', :require => false
gem 'square-hoptoad_notifier', :require => "hoptoad_notifier"

gem 'carrierwave', '~> 0.5.4'
gem 'mysql2', '~> 0.2.7'
gem "symbolize"

gem 'haml'
gem 'haml-rails'
gem 'sass'
gem 'compass'

gem "resque"
gem "resque-lock"
gem "resque-scheduler"
gem "system_timer", :platforms => :mri_18    # used by redis gem

gem "rest-client"

group :development do
  gem 'ruby-debug', :platforms => :mri_18
  gem 'ruby-debug19', :require => 'ruby-debug', :platforms => :mri_19

  gem 'capistrano', :require => false
end

group :test, :development do
  gem 'autotest'
  gem 'autotest-fsevent'
  gem 'rspec-rails'
end

group :test do
  gem "webmock"
end
