require 'spec_helper'
require 'build'

describe BranchDecorator do
  describe "#most_recent_build_state" do
    let(:branch) { instance_double("Branch") }
    let(:decorated_branch) { BranchDecorator.new(branch) }

    context "when at least one build is present" do
      before do
        allow(branch).to receive(:most_recent_build) {
          instance_double("Build", state: 'running')
        }
      end

      it "returns the state of the most recent build" do
        expect(decorated_branch.most_recent_build_state).to eq('running')
      end
    end

    context "there are no builds for the branch" do
      before do
        allow(branch).to receive(:most_recent_build).and_return(nil)
      end

      it "returns 'unknown'" do
        expect(decorated_branch.most_recent_build_state).to eq('unknown')
      end
    end
  end

  describe "#last_build_duration" do
    let(:branch) { instance_double("Branch") }
    let(:decorated_branch) { BranchDecorator.new(branch) }

    context "with a completed build" do
      before do
        allow(branch).to receive(:last_completed_build) {
          instance_double("Build", state: 'succeeded', elapsed_time: 60)
        }
      end

      it "gets the duration of the last completed build" do
        expect(decorated_branch.last_build_duration).to eq(60)
      end
    end

    context "without a completed build" do
      before do
        allow(branch).to receive(:last_completed_build).and_return(nil)
      end

      it "returns nil" do
        expect(decorated_branch.last_build_duration).to be_nil
      end
    end
  end

  describe '#build_time_history' do
    subject { decorated_branch.build_time_history }

    let(:branch) do
      proj = instance_double("Branch")
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
    let(:decorated_branch) { BranchDecorator.new(branch) }

    it "should bucket the builds by type" do
      should == {
        "cucumber" => [@cucumber1, @cucumber2],
        "jasmine" => [@jasmine1, @jasmine2],
        "rubocop" => [@rubocop1, @rubocop2],
      }
    end

    context 'when the branch has never been built' do
      let(:branch) { instance_double("Branch", :timing_data_for_recent_builds => []) }

      it { should == {} }
    end

    context 'when the some build types are missing from builds' do
      let(:branch) do
        proj = instance_double("Branch")
        allow(proj).to receive(:timing_data_for_recent_builds) {
          [
            @pants1 = ["pants", "fb25a", 55, 43, 0, 72550, "succeeded", "2014-03-01 22:45:39 UTC"],
            @findbugs1 = ["findbugs",  "fb25a",  2,  0, 0, 72550, "succeeded", "2014-03-01 22:45:39 UTC"],
            @pants2 = ["pants",  "f4235",  3,  0, 0, 72560, "succeeded", "2014-03-02 00:37:55 UTC"],
            @findbugs2 = ["findbugs", "f4235", 55, 44, 0, 72560, "succeeded", "2014-03-02 00:37:55 UTC"],
            @errorprone2 = ["errorprone",  "f4235",  2,  0, 0, 72560, "succeeded", "2014-03-02 00:37:55 UTC"],
            @pants3 = ["pants",  "ef570",  3,  0, 0, 72568, "succeeded", "2014-03-02 01:23:50 UTC"],
          ]
        }
        proj
      end

      it 'should sort the builds and add empty values for missing build parts' do
        should == {
          'pants' => [@pants1, @pants2, @pants3],
          'findbugs' => [@findbugs1, @findbugs2, []],
          'errorprone' => [[], @errorprone2, []],
        }
      end
    end
  end
end
