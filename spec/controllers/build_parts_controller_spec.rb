require 'spec_helper'

describe BuildPartsController do
  render_views

  let(:build) { FactoryGirl.create(:build) }
  let(:repository) { build.repository }
  let(:build_part) { build.build_parts.create!(:paths => ["a"], :kind => "test", :queue => :ci) }

  describe "#show" do
    it "renders the show template successfully even if elapsed time is nil" do
      expect(build_part.elapsed_time).to eq(nil)
      get :show, repository_path: repository, build_id: build, id: build_part
      expect(response).to be_success
      expect(response).to render_template("build_parts/show")
    end

    it "renders JSON if requested" do
      build_attempt = FactoryGirl.create(:build_attempt, build_part: build_part)
      FactoryGirl.create(:build_artifact, build_attempt: build_attempt)
      get :show, repository_path: repository, build_id: build, id: build_part, format: :json
      ret = JSON.parse(response.body)
      expect(ret['build_part']['build_attempts'].length).to eq(1)
      expect(ret['build_part']['build_attempts'][0]['build_artifacts'].length).to eq(1)
      expect(ret['build_part']['build_attempts'][0]['build_artifacts'][0]['build_attempt_id']).to eq(build_attempt.id)
    end
  end

  describe "#rebuild" do
    subject {
      get :rebuild, repository_path: repository, build_id: build, id: build_part
    }

    it "should redirect to the right place" do
      allow_any_instance_of(Build).to receive(:test_command).and_return("echo just chill")

      subject
      expect(response).to redirect_to(repository_build_path(build.repository, build))
    end

    context "the requested commit SHA no longer exists" do
      before do
        allow_any_instance_of(Build).to receive(:test_command).and_raise(GitRepo::RefNotFoundError)
      end

      it "should not create a new build attempt" do
        build_part  # trigger creation of the db records

        expect {
          subject
        }.to_not change { build_part.build_attempts.count }
      end

      it "should display a flash error" do
        subject
        expect(flash[:error]).to be_present
      end
    end
  end
end
