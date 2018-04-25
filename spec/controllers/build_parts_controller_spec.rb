require 'spec_helper'

describe BuildPartsController do
  render_views

  let(:build) { FactoryBot.create(:build) }
  let(:repository) { build.repository }
  let(:build_part) { build.build_parts.create!(:paths => ["a"], :kind => "test", :queue => 'ci') }

  describe "#show" do
    it "renders the show template successfully even if elapsed time is nil" do
      expect(build_part.elapsed_time).to eq(nil)
      get :show, params: { repository_path: repository, build_id: build, id: build_part }
      expect(response).to be_success
      expect(response).to render_template("build_parts/show")
    end

    it "renders JSON if requested" do
      build_attempt = FactoryBot.create(:build_attempt, build_part: build_part)
      FactoryBot.create(:build_artifact, build_attempt: build_attempt)
      get :show, params: { repository_path: repository, build_id: build, id: build_part, format: :json }
      ret = JSON.parse(response.body)
      expect(ret['build_part']['build_attempts'].length).to eq(1)
      expect(ret['build_part']['build_attempts'][0]['build_artifacts'].length).to eq(1)
      expect(ret['build_part']['build_attempts'][0]['build_artifacts'][0]['build_attempt_id']).to eq(build_attempt.id)
    end

    context "when the repository is disabled" do
      let(:build2) { FactoryBot.create(:build_on_disabled_repo) }
      let(:build_part2) { FactoryBot.create(:build_part, build_instance: build2) }

      it "should not show Rebuild button" do
        get :show, params: { repository_path: build2.repository, build_id: build2, id: build_part2 }
        expect(response.body).to_not match(/class="rebuild button"/)
      end
    end

    context "when the repository is enabled" do
      let(:build2) { FactoryBot.create(:build) }
      let(:build_part2) { FactoryBot.create(:build_part, build_instance: build2) }

      it "should show Rebuild button" do
        get :show, params: { repository_path: build2.repository, build_id: build2, id: build_part2 }
        expect(response.body).to match(/class="rebuild button"/)
      end
    end
  end

  describe "#rebuild" do
    subject {
      get :rebuild, params: { repository_path: repository, build_id: build, id: build_part }
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

  describe '#refresh_build_part_info' do
    it "returns partials for build_attempts" do
      build_attempt = FactoryBot.create(:build_attempt, build_part: build_part)
      FactoryBot.create(:build_artifact, build_attempt: build_attempt)
      get :refresh_build_part_info, params: { repository_path: repository, build_id: build, id: build_part, format: :json }
      res = JSON.parse(response.body)
      expect(res.first['state']).to eq(build_attempt.state)
      expect(res.first['content']).to include("/build_attempts/#{build_attempt.id}/")
    end
  end
end
