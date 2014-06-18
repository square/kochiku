require 'resque-retry'
require 'resque/failure/redis'
require 'resque-retry/server'

Resque.redis = REDIS
Resque.redis.namespace = "resque:kochiku"

Resque::Failure::MultipleWithRetrySuppression.classes = [Resque::Failure::Redis]
Resque::Failure.backend = Resque::Failure::MultipleWithRetrySuppression
