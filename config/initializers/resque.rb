require 'resque-scheduler'
require 'resque-retry'
require 'resque/failure/redis'
require 'resque-retry/server'

Resque.redis = REDIS
Resque.redis.namespace = "resque:kochiku"

# Necessary to specify the schedule file here for the scheduled jobs to appear
# in the resque-web UI
Resque.schedule = YAML.load_file('config/resque_schedule.yml')

Resque::Failure::MultipleWithRetrySuppression.classes = [Resque::Failure::Redis]
Resque::Failure.backend = Resque::Failure::MultipleWithRetrySuppression
