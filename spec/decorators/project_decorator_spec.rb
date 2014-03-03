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
    subject { decorated_project.build_time_history }

    let(:project) do
      proj = instance_double("Project")
      allow(proj).to receive(:timing_data_for_recent_builds) {
        [
          @cucumber1 = ["cucumber", "fb25a", 55, 43, 0, 72550, "succeeded", "2014-03-01 22:45:39 UTC"],
          @jasmine1 = ["jasmine",  "fb25a",  2,  0, 0, 72550, "succeeded", "2014-03-01 22:45:39 UTC"],
          @rubocop1 = ["rubocop",  "fb25a",  3,  0, 0, 72550, "succeeded", "2014-03-01 22:45:39 UTC"],
          @cucumber2 = ["cucumber", "f4235", 55, 44, 0, 72560, "succeeded", "2014-03-02 00:37:55 UTC"],
          @jasmine2 = ["jasmine",  "f4235",  2,  0, 0, 72560, "succeeded", "2014-03-02 00:37:55 UTC"],
          @rubocop2 = ["rubocop",  "f4235",  3,  0, 0, 72560, "succeeded", "2014-03-02 00:37:55 UTC"],
        ]
      }
      proj
    end
    let(:decorated_project) { ProjectDecorator.new(project) }

    it "should bucket the builds by type" do
      should == {
        "cucumber" => [@cucumber1, @cucumber2],
        "jasmine" => [@jasmine1, @jasmine2],
        "rubocop" => [@rubocop1, @rubocop2],
      }
    end

    context 'when the project has never been built' do
      let(:project) { instance_double("Project", :timing_data_for_recent_builds => []) }

      it { should == {} }
    end
  end
end
