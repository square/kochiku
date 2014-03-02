require 'spec_helper'
require 'build'

describe ProjectDecorator do
  describe "#most_recent_build_state" do
    let(:project) { instance_double("Project") }
    let(:decorated_project) { ProjectDecorator.new(project) }

    context "when at least one build is present" do
      before do
        allow(project).to receive(:builds) {
          [
            instance_double("Build", state: :errored),
            instance_double("Build", state: :running)
          ]
        }
      end

      it "returns the state of the most recent build" do
        expect(decorated_project.most_recent_build_state).to be(:running)
      end
    end

    context "there are no builds for the project" do
      before do
        allow(project).to receive(:builds).and_return([])
      end

      it "returns :unknown" do
        expect(decorated_project.most_recent_build_state).to be(:unknown)
      end
    end
  end

  describe "#last_build_duration" do
    let(:project) { instance_double("Project") }
    let(:decorated_project) { ProjectDecorator.new(project) }

    context "with a completed build" do
      before do
        allow(project).to receive_message_chain(:builds, :completed) {
          [
            instance_double("Build", state: :succeeded, elapsed_time: 60)
          ]
        }
      end

      it "gets the duration of the last completed build" do
        expect(decorated_project.last_build_duration).to be_an(Integer)
      end
    end

    context "without a completed build" do
      before do
        allow(project).to receive_message_chain(:builds, :completed).and_return([])
      end

      it "returns nil" do
        expect(decorated_project.last_build_duration).to be_nil
      end
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
