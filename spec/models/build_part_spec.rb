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
      BuildAttemptJob.should_receive(:enqueue_on).once.with("ci-cucumber", anything, anything, anything, anything)
      build_part.create_and_enqueue_new_build_attempt!
    end
  end

  describe "#unsuccessful?" do
    subject { build_part.unsuccessful? }

    context "with all successful attempts" do
      before {
        2.times { Factory(:build_attempt,
                          :build_part => build_part,
                          :state => :passed) }
      }

      it { should be_false }
    end

    context "with one successful attempt" do
      before {
        2.times { Factory(:build_attempt,
                          :build_part => build_part,
                          :state => :failed) }
        Factory(:build_attempt,
                :state => :passed)
      }

      it { should be_true }
    end
  end
end
