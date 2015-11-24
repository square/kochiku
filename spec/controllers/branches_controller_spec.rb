require 'spec_helper'
require 'rexml/document'

describe BranchesController do
  render_views

  describe "#index" do
    let(:repo) { FactoryGirl.create(:repository) }
    let!(:a) { FactoryGirl.create(:branch, name: 'aster', repository: repo, convergence: true) }
    let!(:b) { FactoryGirl.create(:branch, name: 'buckeye', repository: repo) }
    let!(:c) { FactoryGirl.create(:branch, name: 'creosote', repository: repo) }

    it "shows branches in order" do
      get :index, repository_path: repo
      expect(assigns(:convergence_branches).map(&:name)).to eq(%w{aster})
      expect(assigns(:recently_active_branches).map(&:name)).to eq(%w{buckeye creosote})
    end
  end

  describe "#show" do
    let(:branch) { FactoryGirl.create(:branch) }
    let!(:build1) { FactoryGirl.create(:build, :branch_record => branch, :state => :succeeded) }
    let!(:build2) { FactoryGirl.create(:build, :branch_record => branch, :state => :errored) }

    it "should return an rss feed of builds" do
      get :show, repository_path: branch.repository, id: branch, format: :rss
      doc = REXML::Document.new(response.body)
      items = doc.elements.to_a("//channel/item")
      expect(items.length).to eq(Build.count)
      expect(items.first.elements.to_a("title").first.text).to eq("Build Number #{build2.id} failed")
      expect(items.last.elements.to_a("title").first.text).to eq("Build Number #{build1.id} success")
    end

    it "should return a JSON if requested" do
      get :show, repository_path: branch.repository, id: branch, format: :json
      results = JSON.parse(response.body)
      expect(results['id']).to eq(branch.id)
      expect(results['recent_builds'].length).to eq(Build.count)
      expect(results['recent_builds'][0]['build']['id']).to eq(build1.id)
      expect(results['recent_builds'][1]['build']['id']).to eq(build2.id)
    end
  end

  describe "#request_new_build" do
    let(:branch) { FactoryGirl.create(:branch) }
    subject {
      post :request_new_build, repository_path: branch.repository.to_param, id: branch.to_param
    }

    context "when there is a new commit on the branch that hasn't been built" do
      before do
        @sha = to_40('1')
        fake_remote_server = double(:sha_for_branch => @sha)
        allow(RemoteServer).to receive(:for_url).with(branch.repository.url).and_return(fake_remote_server)
      end

      it "should create the new build and redirect there" do
        expect(branch.builds.where(ref: @sha).first).to be_nil

        subject
        new_build = branch.builds.where(ref: @sha).first
        expect(new_build).to be_present

        expect(response).to redirect_to(repository_build_path(branch.repository, new_build))
      end
    end

    context "when kochiku has already built the most recent commit on the branch" do
      let(:branch_head_sha) { "4b41fe773057b2f1e2063eb94814d32699a34541" }

      before do
        FactoryGirl.create(:build, state: :errored, branch_record: branch, ref: branch_head_sha)

        fake_remote_server = double(:sha_for_branch => branch_head_sha)
        allow(RemoteServer).to receive(:for_url).with(branch.repository.url).and_return(fake_remote_server)
      end

      it "should not create a new build" do
        expect { subject }.to_not change { Build.count }

        expect(flash[:error]).to be_nil
        expect(flash[:warn]).to be_present
      end

      it "should redirect to the existing build" do
        subject
        expect(response).to redirect_to(repository_branch_path(branch.repository, branch))
      end
    end
  end

  describe "#health" do
    let(:branch) { FactoryGirl.create(:branch) }

    before do
      build = FactoryGirl.create(:build, branch_record: branch, state: :succeeded)
      build_part = FactoryGirl.create(:build_part, build_instance: build)
      FactoryGirl.create(:completed_build_attempt, build_part: build_part, state: :failed)
      FactoryGirl.create(:completed_build_attempt, build_part: build_part, state: :passed)
    end

    it "should render" do
      get :health, repository_path: branch.repository, id: branch
      expect(response).to be_success
    end
  end

  describe "#build_time_history" do
    # the logic here is tested inside branch_spec and branch_decorator_spec. Just
    # verify that the endpoint responds ok

    let(:branch) { FactoryGirl.create(:branch) }

    before do
      FactoryGirl.create(:completed_build, branch_record: branch)
    end

    it "should render" do
      get :build_time_history, repository_path: branch.repository, id: branch, format: :json
      expect(response).to be_success
    end
  end

  describe "#status_report" do
    let(:repository) { FactoryGirl.create(:repository) }
    let(:branch) { FactoryGirl.create(:master_branch, repository: repository) }

    context "when a branch has no builds" do
      before { expect(branch.builds).to be_empty }

      it "should return 'Unknown' for activity" do
        get :status_report, format: :xml
        expect(response).to be_success

        doc = Nokogiri::XML(response.body)
        element = doc.at_xpath("/Projects/Project[@name='#{repository.to_param}']")

        expect(element['activity']).to eq('Unknown')
      end
    end

    context "with a in-progress build" do
      let!(:build) { FactoryGirl.create(:build, state: :running, branch_record: branch) }

      it "should return 'Building' for activity" do
        get :status_report, format: :xml
        expect(response).to be_success

        doc = Nokogiri::XML(response.body)
        element = doc.at_xpath("/Projects/Project[@name='#{repository.to_param}']")

        expect(element['activity']).to eq('Building')
      end
    end

    context "with a completed build" do
      let!(:build) { FactoryGirl.create(:build, state: :failed, branch_record: branch) }

      it "should return 'CheckingModifications' for activity" do
        get :status_report, format: :xml
        expect(response).to be_success

        doc = Nokogiri::XML(response.body)
        element = doc.at_xpath("/Projects/Project[@name='#{repository.to_param}']")

        expect(element['activity']).to eq('CheckingModifications')
      end
    end

    context "with extra convergence branch and one non-convergence" do
      before do
        FactoryGirl.create(:branch, :name => 'feature-branch', convergence: false, repository: repository)
        FactoryGirl.create(:branch, :name => 'convergence', convergence: true, repository: repository)
      end

      it "should include all of the convergence branches" do
        branch ## Explicitly reference the branch to cause it to load

        get :status_report, format: :xml

        expect(response).to be_success

        doc = Nokogiri::XML(response.body)
        elements = doc.xpath("/Projects/Project")

        expect(elements).to have(2).items

        names = elements.map{ |e| e.attribute("name").to_s }

        expect(names).to match_array(["#{repository.to_param}", "#{repository.to_param}/convergence"])
      end
    end
  end
end
