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
gem "system_timer", :platforms => :mri_18    # used by redis gem

gem "rest-client", :require => false

group :development do
  gem 'ruby-debug', :platforms => :mri_18
  gem 'ruby-debug19', :require => 'ruby-debug', :platforms => :mri_19

  gem 'capistrano', :require => false
end

group :test, :development do
  gem 'autotest-rails', :require => false
  gem 'autotest-fsevent', :require => false
  gem 'rspec-rails'
end

group :test do
  gem "webmock", :require => false
  gem "nokogiri", :require => false
end
