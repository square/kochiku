require 'spec_helper'

describe ProjectDecorator do
  let(:project) { FactoryGirl.create(:project, :name => "kochiku").decorate }

  describe "#most_recent_build_state" do
    context "when at least one build is present" do
      before do
        FactoryGirl.create(:build, :project => project, :state => :errored)
        @most_recent = FactoryGirl.create(:build, :project => project, :state => :running)
      end

      it "returns the state of the most recent build" do
        expect(project.most_recent_build_state).to be(:running)
      end
    end

    context "there are no builds for the project" do
      it "returns :unknown" do
        expect(project.most_recent_build_state).to be(:unknown)
      end
    end
  end

  describe "#last_build_duration" do
    before do
      build = FactoryGirl.create(:build, :project => project, :state => :succeeded)
      build_part = FactoryGirl.create(:build_part, :build_instance => build)
      FactoryGirl.create(:build_attempt, :build_part => build_part, :finished_at => 1.minute.from_now)
    end

    it "gets the last builds duration" do
      expect(project.last_build_duration).not_to be_nil
    end

    it "gets the last successful builds duration" do
      FactoryGirl.create(:build, :project => project, :state => :runnable)
      expect(project.last_build_duration).not_to be_nil
    end
  end

  describe '#build_time_history' do
    subject { project.build_time_history }

    let(:project) { FactoryGirl.create(:project).decorate }

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
