require 'spec_helper'

describe BuildPart do
  let(:build) { FactoryGirl.create(:build) }
  let(:build_part) { build.build_parts.create!(:paths => ["a", "b"], :kind => "test") }

  describe "#rebuild!" do
    it "should create a fresh build attempt" do
      expect {
        build_part.rebuild!
      }.to change(build_part.build_attempts, :count).by(1)
    end

    it "should enqueue the build attempt for building" do
      BuildAttemptJob.should_receive(:enqueue_on).once.with(build.queue, kind_of(Integer))
      build_part.rebuild!
    end
  end
end
