require 'spec_helper'

describe Project do
  describe "#last_build_duration" do
    let(:project) { FactoryGirl.create(:project, :name => "kochiku") }
    before do
      build = FactoryGirl.create(:build, :project => project, :state => :succeeded)
      build_part = FactoryGirl.create(:build_part, :build_instance => build)
      build_attempt = FactoryGirl.create(:build_attempt, :build_part => build_part, :finished_at => 1.minute.from_now)
      build.update_attributes(:state => :succeeded)
    end

    it "gets the last builds duration" do
      project.last_build_duration.should_not be_nil
    end

    it "gets the last successful builds duration" do
      FactoryGirl.create(:build, :project => project, :state => :runnable).reload
      project.last_build_duration.should_not be_nil
    end
  end

  describe "#main?" do
    let(:repository) { FactoryGirl.create(:repository, :url => "git@git.squareup.com:square/kochiku.git") }
    it "returns true when the projects name is the same as the repo" do
      project = FactoryGirl.create(:project, :name => "kochiku", :repository => repository)
      project.main?.should be_true
    end
    it "returns false when the projects name different then the repo" do
      project = FactoryGirl.create(:project, :name => "web", :repository => repository)
      project.main?.should be_false
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
