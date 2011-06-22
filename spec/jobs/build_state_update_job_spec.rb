require 'spec_helper'

describe BuildStateUpdateJob do
  before do
    @build = Build.create!(:sha => "sha", :state => :runnable, :queue => "q")
    @build.build_parts.create!(:kind => :spec, :paths => ["foo", "bar"])
    @build.build_parts.create!(:kind => :cucumber, :paths => ["baz"])
  end
  describe "#perform" do
    context "when incomplete but nothing has failed" do
      before do
        @build.build_parts.first.build_part_results.create!(:result => :passed)
      end

      it "should be running" do
        expect {
          BuildStateUpdateJob.perform(@build.id)
        }.to change { @build.reload.state }.from(:runnable).to(:running)
      end
    end

    context "when all parts have passed" do
      before do
        @build.build_parts.each do |part|
          part.build_part_results.create!(:result => :passed)
        end
      end

      it "should pass the build" do
        expect {
          BuildStateUpdateJob.perform(@build.id)
        }.to change { @build.reload.state }.from(:runnable).to(:succeeded)
      end
    end

    context "when a part has failed but some are still running" do
      before do
        @build.build_parts.first.build_part_results.create!(:result => :failed)
      end

      it "should pass the build" do
        expect {
          BuildStateUpdateJob.perform(@build.id)
        }.to change { @build.reload.state }.from(:runnable).to(:doomed)
      end

    end

    context "when all parts have run and some have failed" do
      before do
        @build.build_parts.each do |part|
          part.build_part_results.create!(:result => :passed)
        end
        @build.build_parts.first.build_part_results.create!(:result => :failed)
      end
      it "should pass the build" do
        expect {
          BuildStateUpdateJob.perform(@build.id)
        }.to change { @build.reload.state }.from(:runnable).to(:succeeded)
      end
    end
  end
end