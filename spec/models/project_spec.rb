require 'spec_helper'

describe Project do
  describe "#main_build?" do
    let(:repository) {Factory.create(:repository, :url => "git@git.squareup.com:square/kochiku.git")}
    it "returns true when the projects name is the same as the repo" do
      project = Factory.create(:project, :name => "kochiku", :repository => repository)
      project.main_build?.should be_true
    end
    it "returns false when the projects name different then the repo" do
      project = Factory.create(:project, :name => "web", :repository => repository)
      project.main_build?.should be_false
    end
  end

  describe '#build_time_history' do
    subject { project.build_time_history }

    let(:project) { Factory.create(:project) }

    context 'when the project has never been built' do
      it { should == { 'min' => 0, 'max' => 0 } }
    end

    context 'when the project has one build' do
      let!(:build) { Factory.create(:build, :project => project, :state => :succeeded) }

      context 'when the build has one part' do
        let!(:build_part) {
          Factory.create(:build_part, :build_instance => build, :kind => 'spec')
        }

        context 'when the part has one attempt' do
          let!(:build_attempt) do
            Factory.create(
              :build_attempt,
              :build_part => build_part,
              :started_at => 12.minutes.ago,
              :finished_at => 7.minutes.ago,
              :state => :passed
            )
          end

          it 'shows a simple series' do
            should == {
              'min' => build.id,
              'max' => build.id,
              'spec' => [[
                build.id,
                (build_attempt.elapsed_time / 60).round,
                (build_attempt.elapsed_time / 60).round
              ]]}
          end
        end
      end
    end
  end
end
