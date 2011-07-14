require 'spec_helper'

describe BuildArtifactsController do
  describe "#create" do
    let(:queue) { :master }
    let(:build) {Build.build_sha!(:sha => "abcdef", :queue => queue) }
    let(:build_part) { BuildPart.create!(:build => build, :paths => ["a"], :kind => "test") }
    let(:build_attempt) { build_part.build_attempts.create!(:state => :failed) }
    
    it "should create a build artifact for the build attempt" do
      log_file = File.open(FIXTURE_PATH.join("build_artifact.log"))
      log_contents = log_file.read
      log_contents.should_not be_empty

      expect {
        post :create, :build_attempt_id => build_attempt.id, :build_artifact => {:log_file => log_file}

      }.to change{build_attempt.build_artifacts.count}.by(1)

      artifact = assigns(:build_artifact)
      artifact.log_file.read.should == log_contents
    end
  end
end
