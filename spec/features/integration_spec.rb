# coding: utf-8
require "spec_helper"

feature "viewing an in process build" do
  let(:repository) { FactoryGirl.create(:repository) }
  let(:project) { FactoryGirl.create(:project, :name => repository.repository_name) }
  let(:build) { FactoryGirl.create(:build, :project => project) }
  let(:build_part) { FactoryGirl.create(:build_part, :build_instance => build)}
  let!(:build_attempt) { FactoryGirl.create(:build_attempt, :build_part => build_part, :state => :runnable)}

  it "view the current status of the build attempts" do
    build.update_attribute(:state, :runnable)

    visit('/')

    page.should have_content(project.name)
    first(".ci-build-info .state").should have_content("Runnable")

    click_link(project.name)
    page.should have_content(build.ref[0, 5])
    click_link(build.ref[0, 5])

    page.should have_content("Runnable on ci queue")

    within("table.build-summary") do
      find("td:nth-child(1)").should have_content(build_part.id)
      find("td:nth-child(2)").should have_content("Runnable")
      find("td:nth-child(4)").should have_content("Test")
      click_link("#{build_part.id}")
    end

    find(".subheader").should have_content("#{build.ref[0,5]} - Part #{build_part.id}")

    all(".build-part-info tbody tr").size.should == 1
  end

  it "should return to the home page when the logo is clicked" do
    # visit a deep page
    visit project_build_part_path(project, build, build_part)

    click_link("Home")

    current_path.should == root_path
    page.should have_content(project.name)
  end
end

feature "a failed build" do
  before :each do
    @build_attempt = FactoryGirl.create(:build_attempt, :state => :failed)
    @build_part = @build_attempt.build_part
  end

  it "can be rebuilt" do
    build_part_page = project_build_part_path(@build_part.project, @build_part.build_instance, @build_part)
    visit(build_part_page)
    all(".build-part-info tbody tr").size.should == 1
    click_link("Rebuild")
    visit(build_part_page)
    all(".build-part-info tbody tr").size.should == 2
  end
end


feature "requesting a developer build" do
  before :each do
    repository = FactoryGirl.create(:repository, :url => "git@git.squareup.com:square/kochiku.git")
    @project = FactoryGirl.create(:project, :name => "kochiku-developer", :repository => repository)
  end
  
  it "creates a new build if a sha is given" do
    visit(project_path(@project))
    fill_in("build_ref", :with => "DEADBEEF")
    click_button('Build')
    page.should have_content("DEADB")
    find(".flash.message").should have_content("Build added!")
  end

  it "shows an error if no sha is given" do
    visit(project_path(@project))
    click_button('Build')
    find(".flash.error").should have_content("Error adding build!")
  end
end
