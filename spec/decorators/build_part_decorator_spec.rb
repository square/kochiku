require 'spec_helper'

describe BuildPartDecorator do
  describe "#most_recent_stdout_artifact" do
    let(:artifact) { FactoryGirl.create(:build_artifact, :log_file => File.open(FIXTURE_PATH + file)) }
    let(:build_attempt) { artifact.build_attempt }
    let(:build_part) { BuildPartDecorator.new(build_attempt.build_part) }

    subject { build_part.most_recent_stdout_artifact }

    before do
      FactoryGirl.create(:build_artifact)
    end

    context "stdout.log" do
      let(:file) { "stdout.log" }
      it { should == artifact }
    end

    context "stdout.log.gz" do
      let(:file) { "stdout.log.gz" }
      it { should == artifact }
    end

    context "not present" do
      let(:file) { "build_artifact.log" }
      it { should be_nil }
    end
  end
end
