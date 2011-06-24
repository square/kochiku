require 'spec_helper'

describe BuildPart do
  let(:queue) { :master }
  let(:build) {Build.build_sha!(:sha => "abcdef", :queue => queue) }
  let(:build_part) { BuildPart.create!(:build => build, :paths => ["a", "b"], :kind => "test") }

  describe "when created" do
    it "enqueues a build part job" do
      BuildPartJob.should_receive(:enqueue_on).with(queue, anything)
      build_part.should be_present
    end
  end

  describe "#status" do
    context "when no status" do
      it "should be runnable" do
        build_part.status.should == :runnable
      end
    end

    context "with a failed status" do
      before {build_part.build_part_results.create!(:state => :failed)}
      it "should be failed" do
        build_part.status.should == :failed
      end

      context "with another failed status" do
        before {build_part.build_part_results.create!(:state => :failed)}
        it "should be failed" do
          build_part.status.should == :failed
        end
      end

      context "with another passed status" do
        before {build_part.build_part_results.create!(:state => :passed)}
        it "should be passed" do
          build_part.status.should == :passed
        end
      end

    end

    context "with a passed status" do
      before {build_part.build_part_results.create!(:state => :passed)}
      it "should be passed" do
        build_part.status.should == :passed
      end

      context "with another failed status" do
        before {build_part.build_part_results.create!(:state => :failed)}
        it "should be passed" do
          build_part.status.should == :passed
        end
      end
    end
  end
end
