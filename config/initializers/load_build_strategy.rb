if Rails.env.test? || Rails.env.development?
  require 'build_strategies/no_op_build_strategy'
else
  require 'build_strategies/production_build_strategy'
end
