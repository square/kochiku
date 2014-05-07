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

  describe "#log_contents" do
    let!(:artifact)       { FactoryGirl.create :build_artifact }
    let!(:artifact_gz) { FactoryGirl.create :build_artifact, :log_file => File.open(FIXTURE_PATH + 'stdout.log.gz') }    

    it "should return the log contents for a log" do
      log_contents = artifact.log_file.read
      expect(artifact.log_contents).to eq(log_contents)
    end

    it "should return the log contents for a gzipped log" do
      infile = open(artifact_gz.log_file.path)
      log_contents = Zlib::GzipReader.new(infile).read
      expect(artifact_gz.log_contents).to eq(log_contents)
    end
  end
end
