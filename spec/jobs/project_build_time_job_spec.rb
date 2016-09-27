require 'spec_helper'

describe ProjectBuildTimeJob do
  let(:repository) { FactoryGirl.create(:repository) }
  let(:branch) { FactoryGirl.create(:branch, repository: repository) }
  let(:build) { FactoryGirl.create(:build, state: :succeeded, branch_record: branch, created_at: 12.hours.ago) }
  let(:job) { FactoryGirl.create(:build_part, build_instance: build, created_at: 12.hours.ago) }
  let(:build_attempt) { FactoryGirl.create(:build_attempt, build_part: job, started_at: 12.hours.ago, finished_at: 11.hours.ago) }
  subject { ProjectBuildTimeJob.perform(repository.id, Time.current.yesterday.beginning_of_day, Time.current) }

  context "job is running" do
    before do
      allow(build).to receive(:includes).and_return(build)
      allow(job).to receive(:includes).and_return(job)
      allow(BuildStatsHelper).to receive(:jobs_waiting_time_pctl).and_return(default_jobs_time_stats)
      allow(BuildStatsHelper).to receive(:builds_running_time_pctl).and_return(default_builds_time_stats)
    end
    it "should finish without exception" do
      expect(ProjectTimeReport).to receive(:create!)
      subject
    end
  end

  private

  def default_jobs_time_stats
    {
      ninety_five_pctl_build_wait_time: 95,
      ninety_pctl_build_wait_time: 90,
      seventy_pctl_build_wait_time: 70,
      fifty_pctl_build_wait_time: 50
    }
  end

  def default_builds_time_stats
    {
      ninety_five_pctl_build_run_time: 95,
      ninety_pctl_build_run_time: 90,
      seventy_pctl_pctl_build_run_time: 70,
      fifty_pctl_build_run_time: 50
    }
  end
end
