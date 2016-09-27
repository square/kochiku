require 'spec_helper'

describe KochikuWeeklyBuildTimeJob do
  let(:build) { FactoryGirl.create(:build, state: :succeeded, created_at: 12.hours.ago) }
  let(:job) { FactoryGirl.create(:build_part, build_instance: build, created_at: 12.hours.ago) }
  subject { KochikuWeeklyBuildTimeJob.perform }

  context "job is running" do
    before do
      allow(build).to receive(:includes).and_return(build)
      allow(job).to receive(:includes).and_return(job)
    end
    it "should finish without exception" do
      expect(KochikuTimeReport).to receive(:create!)
      subject
    end
  end
end
