require 'spec_helper'

describe ProjectBuildQuantityJob do
  let!(:repository) { FactoryGirl.create(:repository) }
  let(:branch) { FactoryGirl.create(:branch, repository: repository) }
  let(:build) { FactoryGirl.create(:build, state: :succeeded, branch_record: branch, created_at: 12.hours.ago) }
  let(:job) { FactoryGirl.create(:build_part, build_instance: build, created_at: 12.hours.ago) }
  subject { ProjectBuildQuantityJob.perform(repository.id, Time.current.yesterday.beginning_of_day, Time.current) }

  context "job is running" do
    it "should finish without exception" do
      expect(ProjectQuantityReport).to receive(:create!)
      subject
    end
  end
end
