require 'spec_helper'

describe BuildArtifact do
  it "should validate presence of log_file" do
    expect(BuildArtifact.new).not_to be_valid

    ba = BuildArtifact.new
    ba.log_file = File.open(FIXTURE_PATH.join('build_artifact.log'))
    expect(ba).to be_valid
  end

  describe "junit_log scope" do
    let!(:artifact)       { FactoryGirl.create :build_artifact }
    let!(:junit_artifact) { FactoryGirl.create :build_artifact, :log_file => File.open(FIXTURE_PATH + 'rspec.xml.log.gz') }

    subject { BuildArtifact.junit_log }

    it "should return artifacts that match rspec.xml.log" do
      should_not include(artifact)
      should include(junit_artifact)
    end
  end
end
