RSpec::Matchers.define :a_string do |x|
  match { |actual| actual.instance_of?(String) }
end

RSpec::Matchers.define :a_logger do |x|
  match { |actual| actual.has_key?(:logger) }
end
