RSpec::Matchers.define :a_string do |x|
  match { |actual| actual.instance_of?(String) }
end
