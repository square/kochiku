# coding: utf-8
require "spec_helper"

feature "viewing an in process build" do
  let(:project) { FactoryGirl.create(:main_project) }
  let(:build) { FactoryGirl.create(:build, :project => project) }
  let(:build_part) { FactoryGirl.create(:build_part, :build_instance => build, :queue => 'ci')}
  let!(:build_attempt) { FactoryGirl.create(:build_attempt, :build_part => build_part, :state => :runnable)}

  it "view the current status of the build attempts" do
    build.update_attribute(:state, :runnable)

    visit('/')

    expect(page).to have_content(project.name)
    expect(first(".ci-build-info .state")).to have_content("Runnable")

    click_link(project.name)
    expect(page).to have_content(build.ref[0, 5])
    click_link(build.ref[0, 5])

    within("table.build-summary") do
      expect(find("td:nth-child(1)")).to have_content(build_part.id)
      expect(find("td:nth-child(2)")).to have_content("Runnable")
      expect(find("td:nth-child(4)")).to have_content("test")
      click_link("#{build_part.id}")
    end

    expect(find(".subheader")).to have_content("#{build.ref[0, 7]} – #{build_part.kind} (part #{build_part.id})")

    expect(all(".build-part-info tbody tr").size).to eq(1)
  end

  it "should return to the home page when the logo is clicked" do
    # visit a deep page
    visit project_build_part_path(project, build, build_part)
    expect(page).to have_content("Runnable on ci queue")

    click_link("Home")

    expect(current_path).to eq(root_path)
    expect(page).to have_content(project.name)
  end
end

feature "a failed build" do
  before :each do
    @build_attempt = FactoryGirl.create(:build_attempt, :state => :failed)
    @build_part = @build_attempt.build_part
    allow(GitRepo).to receive(:load_kochiku_yml).and_return(nil)
  end

  it "can be rebuilt" do
    build_part_page = project_build_part_path(@build_part.project, @build_part.build_instance, @build_part)
    visit(build_part_page)
    expect(all(".build-part-info tbody tr").size).to eq(1)
    click_link("Rebuild")
    visit(build_part_page)
    expect(all(".build-part-info tbody tr").size).to eq(2)
  end
end


feature "requesting a developer build" do
  before :each do
    repository = FactoryGirl.create(:repository, :url => "git@github.com:square/kochiku.git")
    @project = FactoryGirl.create(:project, :name => "kochiku-developer", :repository => repository)

    @branch = "test/branch"
    @branch_head_sha = "4b41fe773057b2f1e2063eb94814d32699a34541"

    build_ref_info = <<RESPONSE
{
  "ref": "refs/heads/#{@branch}",
  "url": "#{repository.base_api_url}/git/refs/heads/#{@branch}",
  "object": {
    "sha": "#{@branch_head_sha}",
    "type": "commit",
    "url": "#{repository.base_api_url}/git/commits/#{@branch_head_sha}"
  }
}
RESPONSE
    stub_request(:get, "#{repository.base_api_url}/git/refs/heads/#{@branch}").to_return(:status => 200, :body => build_ref_info)
  end

  it "creates a new build if a branch is given" do
    visit(project_path(@project))
    fill_in("build_branch", :with => @branch)
    click_button('Build')
    expect(page).to have_content(@branch_head_sha[0..4])
    expect(find(".flash.message")).to have_content("Build added!")
  end

  it "shows an error if no sha is given" do
    visit(project_path(@project))
    click_button('Build')
    expect(find(".flash.error")).to have_content("Error adding build!")
  end
end
