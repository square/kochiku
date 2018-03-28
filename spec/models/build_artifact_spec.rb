require 'spec_helper'

describe BuildArtifact do
  it "should validate presence of log_file" do
    expect(BuildArtifact.new).not_to be_valid

    ba = BuildArtifact.new
    ba.log_file = File.open(FIXTURE_PATH.join('build_artifact.log'))
    expect(ba).to be_valid
  end

  describe "stdout_log scope" do
    let!(:artifact) { FactoryBot.create :build_artifact }
    let!(:stdout_artifact) { FactoryBot.create :build_artifact, :log_file => File.open(FIXTURE_PATH + 'stdout.log.gz') }

    subject { BuildArtifact.stdout_log }

    it "should return artifacts that match stdout.log" do
      should_not include(artifact)
      should include(stdout_artifact)
    end
  end
end
