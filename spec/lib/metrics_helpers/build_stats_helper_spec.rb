require 'spec_helper'
require 'metrics_helpers/build_stats_helper'

describe BuildStatsHelper do
  describe "#jobs_waiting_time_pctl" do
    context "when there are no jobs" do
      it "should return default result" do
        expect(BuildStatsHelper.jobs_waiting_time_pctl([])).to eq(default_jobs_wait_time_res)
      end
    end

    context "when no valid jobs were found" do
      let(:jobs) { FactoryGirl.create_list(:build_part, 3) }

      before do
        allow_any_instance_of(BuildPart).to receive(:start_at?).and_return(nil)
        allow(jobs).to receive(:includes).and_return(jobs)
      end
      it "should return default result" do
        expect(BuildStatsHelper.jobs_waiting_time_pctl(jobs)).to eq(default_jobs_wait_time_res)
      end
    end

    context "when all data is valid" do
      let(:jobs) { craft_jobs(10) }

      before do
        allow(jobs).to receive(:includes).and_return(jobs)
      end

      it "should return correct value" do
        expect(BuildStatsHelper.jobs_waiting_time_pctl(jobs)).to eq('0.95' => 10, '0.9' => 10, '0.7' => 8, '0.5' => 6)
      end
    end
  end

  describe "#builds_running_time_pctl" do
    context "when there are no builds" do
      it "should return default result" do
        expect(BuildStatsHelper.builds_running_time_pctl([])).to eq(default_builds_wait_time_res)
      end
    end

    context "when no valid builds were found" do
      let(:builds) { FactoryGirl.create_list(:build, 3) }

      before do
        allow_any_instance_of(Build).to receive(:state).and_return(:failed)
        allow(builds).to receive(:includes).and_return(builds)
      end

      it "should return default result" do
        expect(BuildStatsHelper.builds_running_time_pctl(builds)).to eq(default_builds_wait_time_res)
      end
    end

    context "when all data is valid" do
      let(:builds) { craft_builds(10) }

      before do
        allow(builds).to receive(:includes).and_return(builds)
      end

      it "should return correct value" do
        expect(BuildStatsHelper.builds_running_time_pctl(builds)).to eq('0.95' => 9, '0.9' => 9, '0.7' => 7, '0.5' => 5)
      end
    end
  end

  private

  def default_jobs_wait_time_res
    { '0.95' => 0, '0.9' => 0, '0.7' => 0, '0.5' => 0 }
  end

  def default_builds_wait_time_res
    { '0.95' => 0, '0.9' => 0, '0.7' => 0, '0.5' => 0 }
  end

  def craft_jobs(n)
    ret = []
    n.times do |i|
      job = FactoryGirl.create(:build_part, created_at: Time.current)
      FactoryGirl.create(:build_attempt, build_part: job, started_at: job.created_at + i + 1)
      ret << job
    end
    ret
  end

  def craft_builds(n)
    ret = []
    n.times do |i|
      build = FactoryGirl.create(:build, state: :succeeded)
      job = FactoryGirl.create(:build_part, build_instance: build)
      FactoryGirl.create(:build_attempt, build_part: job, started_at: Time.current, finished_at: Time.current + i + 1)
      ret << build
    end
    ret
  end
end
