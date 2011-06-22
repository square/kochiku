require 'spec_helper'

describe BuildPartJob do
  let(:valid_attributes) do
    {
        :build => Build.build_sha!(:sha => sha, :queue => queue),
        :paths => ["a", "b"]
    }
  end

  let(:sha) { "abcdef" }
  let(:queue) { "master" }
  let(:build_part) { BuildPart.create!(valid_attributes) }
  subject { BuildPartJob.new(build_part.id) }

  describe "#perform" do
    it "resets the working directory to the current sha" do
      subject.should_receive(:setup).with(sha)
      subject.perform
    end

    context "build is successful" do
      before { subject.stub(:tests_green? => true) }

      it "creates a build result with a passed result" do
        expect { subject.perform }.to change(build_part.build_part_results, :count).by(1)
        build_part.build_part_results.last.result.should == :passed
      end
    end

    context "build is unsuccessful" do
      before { subject.stub(:tests_green? => false) }

      it "creates a build result with a failed result" do
        expect { subject.perform }.to change(build_part.build_part_results, :count).by(1)
        build_part.build_part_results.last.result.should == :failed
      end
    end
  end
end