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

end
