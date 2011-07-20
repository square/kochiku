require 'spec_helper'

describe BuildStateUpdateJob do
  before do
    @build = Build.create!(:project => projects(:big_rails_app), :sha => "sha", :state => :runnable, :queue => "q")
    @build.build_parts.create!(:kind => :spec, :paths => ["foo", "bar"])
    @build.build_parts.create!(:kind => :cucumber, :paths => ["baz"])
  end
  describe "#perform" do
    context "when incomplete but nothing has failed" do
      before do
        @build.build_parts.first.build_attempts.create!(:state => :passed)
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
          part.build_attempts.create!(:state => :passed)
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
        @build.build_parts.first.build_attempts.create!(:state => :failed)
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
          part.build_attempts.create!(:state => :passed)
        end
        @build.build_parts.first.build_attempts.create!(:state => :failed)
      end
      it "should pass the build" do
        expect {
          BuildStateUpdateJob.perform(@build.id)
        }.to change { @build.reload.state }.from(:runnable).to(:succeeded)
      end
    end

    context "when no parts" do
      before do
        @build.build_parts.destroy_all
      end
      it "should not update the state" do
        expect {
          BuildStateUpdateJob.perform(@build.id)
        }.to_not change { @build.reload.state }
      end
    end
  end
end
