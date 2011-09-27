Resque.redis.namespace = "resque:kochiku"

REDIS_DBS = {:production => 0, :development => 1, :test => 2}.with_indifferent_access
Resque.redis = Redis.new(:db => REDIS_DBS[Rails.env.to_s])
