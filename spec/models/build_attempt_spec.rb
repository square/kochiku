require 'spec_helper'

describe BuildAttempt do
  it "requires a valid state" do
    ba = BuildAttempt.new(:state => "asasdfsdf")
    ba.should_not be_valid
    ba.should have(1).errors_on(:state)
    ba.state = :runnable
    ba.should be_valid
  end
end
