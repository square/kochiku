require 'spec_helper'

describe BuildPart do
  let(:project) { FactoryGirl.create(:big_rails_project) }
  let(:queue) { :ci }
  let(:build) { FactoryGirl.create(:build, :project => project, :queue => queue)}
  let(:build_part) { build.build_parts.create!(:paths => ["a", "b"], :kind => "test") }

  describe "when created" do
    it "enqueues a build part job" do
      BuildPartJob.should_receive(:enqueue_on).with(queue, anything)
      build_part.should be_present
    end
    it "creates a runnable build attempt" do
      build_part.build_attempts.should be_present
      build_part.build_attempts.first.state.should == :runnable
    end
  end
end
