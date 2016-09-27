require 'spec_helper'

describe KochikuDailyBuildQuantityJob do
  let(:build) { FactoryGirl.create(:build, state: :succeeded, created_at: 12.hours.ago) }
  let(:job) { FactoryGirl.create(:build_part, build_instance: build, created_at: 12.hours.ago) }
  subject { KochikuDailyBuildQuantityJob.perform }

  context "job is running" do
    it "should finish without exception" do
      expect(KochikuQuantityReport).to receive(:create!)
      subject
    end
  end
end
