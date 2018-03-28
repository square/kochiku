require 'spec_helper'

describe BuildArtifactsController do
  describe "#create" do
    let(:build) { FactoryBot.create(:build) }
    let(:build_part) { build.build_parts.create!(:paths => ["a"], :kind => "test", :queue => 'ci') }
    let(:build_attempt) { build_part.build_attempts.create!(:state => 'failed') }
    let(:log_file) { fixture_file_upload("/build_artifact.log", 'text/xml') }

    it "should create a build artifact for the build attempt" do
      log_contents = log_file.read
      expect(log_contents).not_to be_empty

      expect {
        post :create, params: { :build_attempt_id => build_attempt.to_param, :build_artifact => {:log_file => log_file}, :format => :xml }
      }.to change{ build_attempt.build_artifacts.count }.by(1)

      artifact = assigns(:build_artifact)
      expect(artifact.log_file.read).to eq(log_contents)
    end

    it "should return the correct location" do
      post :create, params: { :build_attempt_id => build_attempt.to_param, :build_artifact => {:log_file => log_file}, :format => :xml }
      expect(response).to be_success
      expect(response.location).to eq(assigns(:build_artifact).log_file.url)
    end
  end
end
