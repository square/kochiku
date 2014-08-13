require 'spec_helper'

describe Project do
  describe '#ensure_master_build_exists' do
    let(:project) { FactoryGirl.create(:project) }

    it 'creates a new build only if one does not exist' do
      build1 = project.ensure_master_build_exists(to_40('abcdef'))
      build2 = project.ensure_master_build_exists(to_40('abcdef'))
      expect(build1).not_to eq(nil)
      expect(build1).to eq(build2)
    end
  end

  describe '#ensure_branch_build_exists' do
    let(:project) { FactoryGirl.create(:project) }

    it 'creates a new build only if one does not exist' do
      build1 = project.ensure_branch_build_exists('mybranch', to_40('abcdef'))
      build2 = project.ensure_branch_build_exists('mybranch', to_40('abcdef'))
      expect(build1).not_to eq(nil)
      expect(build1).to eq(build2)
      expect(build1.branch).to eq('mybranch')
    end

    it 'aborts previous builds if the current build is a new build' do
      build1 = project.ensure_branch_build_exists('mybranch', '2df46538332f4f3216b5bfa015ecc39e63d5e725')
      build2 = project.ensure_branch_build_exists('mybranch', '4025f76f8a6b2a31431caf4f1a9074675fefc641')
      expect(build1.reload).to be_aborted
      expect(build2.reload).not_to be_aborted
    end

    it 'does abort build if the build is already running' do
      build1 = project.ensure_branch_build_exists('mybranch', to_40('abcdef'))
      expect(build1.reload).not_to be_aborted

      build2 = project.ensure_branch_build_exists('mybranch', to_40('abcdef'))
      expect(build2.reload).not_to be_aborted

      expect(build1).not_to be_aborted
      expect(build1).to eq(build2)
    end
  end

  describe '#abort_in_progress_builds_for_branch' do
    let(:project) { FactoryGirl.create(:project) }

    it 'aborts non-finished builds for a branch' do
      build1 = project.ensure_branch_build_exists('mybranch', to_40('1'))
      build2 = project.ensure_branch_build_exists('mybranch', to_40('2'))
      build3 = project.ensure_branch_build_exists('mybranch', to_40('3'))
      build1.update!(state: :succeeded)

      expect(build2.state).to eq(:partitioning)
      expect(build3.state).to eq(:partitioning)

      project.abort_in_progress_builds_for_branch('mybranch', build3)

      expect(build1.reload.state).to eq(:succeeded)
      expect(build2.reload.state).to eq(:aborted)
      expect(build3.reload.state).to eq(:partitioning)
    end
  end

  describe "#main?" do
    let(:repository) { FactoryGirl.create(:repository, :url => "git@git.example.com:square/kochiku.git") }
    it "returns true when the projects name is the same as the repo" do
      project = FactoryGirl.create(:project, :name => "kochiku", :repository => repository)
      expect(project.main?).to be true
    end
    it "returns false when the projects name different then the repo" do
      project = FactoryGirl.create(:project, :name => "web", :repository => repository)
      expect(project.main?).to be false
    end
  end

  describe "#last_completed_build" do
    let(:project) { FactoryGirl.create(:project) }
    subject { project.last_completed_build }

    it "should return the most recent build in a completed state" do
      FactoryGirl.create(:build, :project => project, :state => :running)
      FactoryGirl.create(:build, :project => project, :state => :succeeded)
      expected = FactoryGirl.create(:build, :project => project, :state => :errored)
      FactoryGirl.create(:build, :project => project, :state => :partitioning)

      should == expected
    end
  end

  describe '#timing_data_for_recent_builds' do
    subject { project.timing_data_for_recent_builds.to_a }

    let(:project) { FactoryGirl.create(:project) }

    context 'when the project has never been built' do
      it { should == [] }
    end

    context 'when the project has one build' do
      let!(:build) { FactoryGirl.create(:build, :project => project, :state => :succeeded) }

      context 'when the build has one part' do
        let!(:build_part) {
          FactoryGirl.create(:build_part, :build_instance => build, :kind => 'spec')
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
            FactoryGirl.create(
              :build_attempt,
              :build_part => build_part,
              :state => :runnable
            )
          end

          it 'still includes the build' do
            build_attempt.finish!(:running)
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
            FactoryGirl.create(
              :build_attempt,
              :build_part => build_part,
              :started_at => 12.minutes.ago,
              :finished_at => 7.minutes.ago,
              :state => :passed
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
