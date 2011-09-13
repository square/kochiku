require 'spec_helper'

describe BuildPart do
  let(:build) { FactoryGirl.create(:build, :queue => :ci) }
  let(:build_part) { build.build_parts.create!(:paths => ["a", "b"], :kind => "cucumber") }

  describe "#create_and_enqueue_new_build_attempt!" do
    it "should create a new build attempt" do
      expect {
        build_part.create_and_enqueue_new_build_attempt!
      }.to change(build_part.build_attempts, :count).by(1)
    end

    it "should enqueue the build attempt for building" do
      # the queue name should include the queue name of the build instance and the type of the test file
      BuildAttemptJob.should_receive(:enqueue_on).once.with("ci-cucumber", kind_of(Integer))
      build_part.create_and_enqueue_new_build_attempt!
    end
  end
end
