require 'spec_helper'

describe Project do
  describe '#ensure_master_build_exists' do
    let(:project) { FactoryGirl.create(:project) }

    it 'creates a new build only if one does not exist' do
      build1 = project.ensure_master_build_exists('abc123')
      build2 = project.ensure_master_build_exists('abc123')
      expect(build1).not_to eq(nil)
      expect(build1).to eq(build2)
    end
  end

  describe '#ensure_branch_build_exists' do
    let(:project) { FactoryGirl.create(:project) }

    it 'creates a new build only if one does not exist' do
      build1 = project.ensure_branch_build_exists('mybranch', 'abc123')
      build2 = project.ensure_branch_build_exists('mybranch', 'abc123')
      expect(build1).not_to eq(nil)
      expect(build1).to eq(build2)
    end

    it 'aborts previous builds if the current build is a new build' do
      build1 = project.ensure_branch_build_exists('mybranch', 'abc123')
      build2 = project.ensure_branch_build_exists('mybranch', 'def456')
      expect(build1.reload).to be_aborted
      expect(build2.reload).not_to be_aborted
    end

    it 'does abort build if the build is already running' do
      build1 = project.ensure_branch_build_exists('mybranch', 'abc123')
      expect(build1.reload).not_to be_aborted

      build2 = project.ensure_branch_build_exists('mybranch', 'abc123')
      expect(build2.reload).not_to be_aborted

      expect(build1).not_to be_aborted
      expect(build1).to eq(build2)
    end
  end

  describe '#abort_in_progress_builds_for_branch' do
    let(:project) { FactoryGirl.create(:project) }

    it 'aborts non-finished builds for a branch' do
      build1 = project.ensure_branch_build_exists('mybranch', 'abc123')
      build2 = project.ensure_branch_build_exists('mybranch', 'efg456')
      build3 = project.ensure_branch_build_exists('mybranch', 'hij789')
      build1.state = :succeeded
      build1.save!

      expect(build2.state).to eq(:partitioning)
      expect(build3.state).to eq(:partitioning)

      project.abort_in_progress_builds_for_branch('mybranch', build3)

      expect(build1.reload).to be_succeeded
      expect(build2.reload).to be_aborted
      expect(build3.reload.state).to eq(:partitioning)
    end
  end

  describe "#last_build_duration" do
    let(:project) { FactoryGirl.create(:project, :name => "kochiku") }
    before do
      build = FactoryGirl.create(:build, :project => project, :state => :succeeded)
      build_part = FactoryGirl.create(:build_part, :build_instance => build)
      build_attempt = FactoryGirl.create(:build_attempt, :build_part => build_part, :finished_at => 1.minute.from_now)
      build.update_attributes(:state => :succeeded)
    end

    it "gets the last builds duration" do
      expect(project.last_build_duration).not_to be_nil
    end

    it "gets the last successful builds duration" do
      FactoryGirl.create(:build, :project => project, :state => :runnable).reload
      expect(project.last_build_duration).not_to be_nil
    end
  end

  describe "#main?" do
    let(:repository) { FactoryGirl.create(:repository, :url => "git@git.example.com:square/kochiku.git") }
    it "returns true when the projects name is the same as the repo" do
      project = FactoryGirl.create(:project, :name => "kochiku", :repository => repository)
      expect(project.main?).to be_true
    end
    it "returns false when the projects name different then the repo" do
      project = FactoryGirl.create(:project, :name => "web", :repository => repository)
      expect(project.main?).to be_false
    end
  end

  describe '#build_time_history' do
    subject { project.build_time_history }

    let(:project) { FactoryGirl.create(:project) }

    context 'when the project has never been built' do
      it { should == {} }
    end

    context 'when the project has one build' do
      let!(:build) { FactoryGirl.create(:build, :project => project, :state => :succeeded) }

      context 'when the build has one part' do
        let!(:build_part) {
          FactoryGirl.create(:build_part, :build_instance => build, :kind => 'spec')
        }

        context 'when the part has zero attempts' do
          it 'still includes the build' do
            should == {
              'spec' => [[
                           build.ref[0, 5],
                           0, 0, 0,
                           build.id,
                           'succeeded',
                           build.created_at.to_s
                         ]]}
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
            should == {
              'spec' => [[
                           build.ref[0, 5],
                           0, 0, 0,
                           build.id,
                           'running',
                           build.created_at.to_s
                         ]]}
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
            should == {
              'spec' => [[
                           build.ref[0, 5],
                           (build_attempt.elapsed_time / 60).round,
                           0, 0,
                           build.id,
                           'succeeded',
                           build.created_at.to_s
                         ]]}
          end
        end
      end
    end
  end
end
