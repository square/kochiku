require 'spec_helper'

describe BuildStateUpdateJob do
  before do
    @project = FactoryGirl.create(:big_rails_project)
    @build = FactoryGirl.create(:build, :state => :runnable, :project => @project)
    @build.build_parts.create!(:kind => :spec, :paths => ["foo", "bar"])
    @build.build_parts.create!(:kind => :cucumber, :paths => ["baz"])

    GitRepo.stub(:run!)
    BuildStrategy.stub(:promote_build)
  end

  shared_examples "a non promotable state" do
    it "should not promote the build" do
      BuildStateUpdateJob.perform(@build.id)
      BuildStrategy.should_not_receive(:promote_build)
    end
  end


  describe "#perform" do
    before do
      stub_request(:post, /https:\/\/git\.squareup\.com\/api\/v3\/repos\/square\/kochiku\/statuses\//)
    end

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

      it "should promote the build" do
        BuildStrategy.should_receive(:promote_build).with(@build.ref, @build.repository)
        BuildStateUpdateJob.perform(@build.id)
      end

      it "should automerge the build" do
        @build.update_attributes(:auto_merge => true, :queue => :developer)
        BuildStrategy.should_receive(:merge_ref).with(@build)
        BuildStateUpdateJob.perform(@build.id)
      end
    end

    context "when a part has failed but some are still running" do
      before do
        @build.build_parts.first.build_attempts.create!(:state => :failed)
      end

      it "should doom the build" do
        expect {
          BuildStateUpdateJob.perform(@build.id)
        }.to change { @build.reload.state }.from(:runnable).to(:doomed)
      end

      it_behaves_like "a non promotable state"
    end

    context "when all parts have run and some have failed" do
      before do
        @build.build_parts.each do |part|
          part.build_attempts.create!(:state => :passed)
        end
        @build.build_parts.first.build_attempts.create!(:state => :failed)
      end

      it "should fail the build" do
        expect {
          BuildStateUpdateJob.perform(@build.id)
        }.to change { @build.reload.state }.from(:runnable).to(:failed)
      end

      it_behaves_like "a non promotable state"
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

      it_behaves_like "a non promotable state"

    end
  end
end
