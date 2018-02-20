require 'spec_helper'

describe TimeoutStuckBuildsJob do
  let(:repository) { FactoryGirl.create(:repository, url: 'git@github.com:square/test-repo.git', assume_lost_after: 10) }
  let(:branch) { FactoryGirl.create(:branch, :repository => repository) }
  let(:build) { FactoryGirl.create(:build, :state => :runnable, :branch_record => branch) }

  subject { TimeoutStuckBuildsJob.perform }

  describe "#perform" do
    let(:build_attempt) {
      build.build_parts.create!(:kind => :spec, :paths => ["foo", "bar"], :queue => :ci)
           .build_attempts.create!(:state => :running)
    }
    let(:build_attempt_2) {
      build.build_parts.create!(:kind => :cucumber, :paths => ["baz"], :queue => :ci)
           .build_attempts.create!(:state => :running)
    }
    context "when a repository has assume_lost_after set" do
      it "should not stop builds that have yet to reach the limit" do
        subject
        expect(build_attempt.reload.state).to eq(:running)
        expect(build_attempt_2.reload.state).to eq(:running)
      end

      it "should stop builds that have reached the limit" do
        expect(build_attempt.state).to eq(:running)
        build_attempt.update_attributes(started_at: 30.minutes.ago)
        subject
        expect(build_attempt.reload.state).to eq(:errored)
        expect(build_attempt_2.reload.state).to eq(:running)
      end
    end

    context "when a build attempt was created more then 5 minutes ago" do
      let(:build_attempt) {
        build.build_parts.create!(:kind => :cucumber, :paths => ["baz"], :queue => :ci)
             .build_attempts.create!(:created_at => 10.minutes.ago, :state => :runnable, :builder => "test")
      }

      it "should stop a build that is not queued" do
        expect(build_attempt.state).to eq(:runnable)
        subject
        expect(build_attempt.reload.state).to eq(:errored)
      end
    end
  end
end
