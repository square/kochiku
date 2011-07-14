require 'spec_helper'

describe BuildArtifact do
  it "should validate presence of log_file" do
    BuildArtifact.new.should_not be_valid

    ba = BuildArtifact.new
    ba.log_file = File.open(FIXTURE_PATH.join('build_artifact.log'))
    ba.should be_valid
  end
end
