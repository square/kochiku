# Load DSL and Setup Up Stages
require 'capistrano/setup'

# Includes default deployment tasks
require 'capistrano/deploy'

# Includes tasks from other gems included in your Gemfile
require 'capistrano/bundler'
require 'capistrano/rails'

# If you would like to use a Ruby version manager with kochiku
# require it from a .cap file in lib/capistrano/tasks/.
#
# For more information see:
# http://capistranorb.com/documentation/frameworks/rbenv-rvm-chruby/

# Loads custom tasks from `lib/capistrano/tasks' if you have any defined.
Dir.glob('lib/capistrano/tasks/*.cap').sort.each { |r| import r }
