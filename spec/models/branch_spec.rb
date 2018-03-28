require 'spec_helper'

RSpec.describe Branch, type: :model do

  it 'should fail on nil name' do
    expect(FactoryBot.build(:branch, name: nil).valid?).to be false
  end

  it 'should fail on empty name' do
    expect(FactoryBot.build(:branch, name: "").valid?).to be false
  end

  describe '#abort_in_progress_builds_behind_build' do
    let(:branch) { FactoryBot.create(:branch) }

    it 'aborts non-finished builds for a branch' do
      build1 = branch.builds.create(state: 'succeeded', ref: to_40('1'))
      build2 = branch.builds.create(state: 'running', ref: to_40('2'))
      build3 = branch.builds.create(state: 'partitioning', ref: to_40('3'))
      build4 = branch.builds.create(state: 'partitioning', ref: to_40('4'))
      build5 = branch.builds.create(state: 'partitioning', ref: to_40('5'))

      branch.abort_in_progress_builds_behind_build(build4)

      expect(build1.reload.state).to eq('succeeded')
      expect(build2.reload.state).to eq('aborted')
      expect(build3.reload.state).to eq('aborted')
      expect(build4.reload.state).to eq('partitioning')
      expect(build5.reload.state).to eq('partitioning')
    end
  end

  describe "#last_completed_build" do
    let(:branch) { FactoryBot.create(:branch) }
    subject { branch.last_completed_build }

    it "should return the most recent build in a completed state" do
      FactoryBot.create(:build, :branch_record => branch, :state => 'running')
      FactoryBot.create(:build, :branch_record => branch, :state => 'succeeded')
      expected = FactoryBot.create(:build, :branch_record => branch, :state => 'errored')
      FactoryBot.create(:build, :branch_record => branch, :state => 'partitioning')

      should == expected
    end
  end

  describe '#timing_data_for_recent_builds' do
    subject { branch.timing_data_for_recent_builds.to_a }

    let(:branch) { FactoryBot.create(:branch) }

    context 'when the branch has never been built' do
      it { should == [] }
    end

    context 'when the branch has one build' do
      let!(:build) { FactoryBot.create(:build, :branch_record => branch, :state => 'succeeded') }

      context 'when the build has one part' do
        let!(:build_part) {
          FactoryBot.create(:build_part, :build_instance => build, :kind => 'spec')
        }

        context 'when the part has zero attempts' do
          it 'still includes the build' do
            should == [[
              'spec',
              build.ref[0, 5],
              0, 0, 0,
              build.id,
              'succeeded',
              build.created_at.to_s
            ]]
          end
        end

        context 'when the part has an unstarted attempt' do
          let!(:build_attempt) do
            FactoryBot.create(
              :build_attempt,
              :build_part => build_part,
              :state => 'runnable'
            )
          end

          it 'still includes the build' do
            build_attempt.finish!('running')
            should == [[
              'spec',
              build.ref[0, 5],
              0, 0, 0,
              build.id,
              'running',
              build.created_at.to_s
            ]]
          end
        end

        context 'when the part has one attempt' do
          let!(:build_attempt) do
            FactoryBot.create(
              :build_attempt,
              :build_part => build_part,
              :started_at => 12.minutes.ago,
              :finished_at => 7.minutes.ago,
              :state => 'passed'
            )
          end

          it 'shows error bars, ref, and build status' do
            should == [[
              'spec',
              build.ref[0, 5],
              (build_attempt.elapsed_time / 60).round,
              0, 0,
              build.id,
              'succeeded',
              build.created_at.to_s
            ]]
          end
        end
      end
    end
  end
end
