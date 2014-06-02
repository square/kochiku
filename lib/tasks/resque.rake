require 'resque/tasks'
require 'resque_scheduler/tasks'

namespace :resque do
  task :setup => [:environment] do
    Resque.schedule = YAML.load_file('config/resque_schedule.yml')
  end
end
