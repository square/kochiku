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

end
