require 'spec_helper'

describe BuildPart do
  describe "when created" do
    let(:build) {Build.build_sha!(:sha => "abcdef", :queue => queue) }
    let(:build_part) { BuildPart.create!(:build => build, :paths => ["a", "b"]) }

    let(:queue) { :master }
    
    it "enqueues a build part job" do
      BuildPartJob.should_receive(:enqueue_on).with(queue, anything)
      build_part.should be_present
    end
  end
end
