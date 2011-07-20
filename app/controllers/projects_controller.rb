class ProjectsController < ApplicationController
  def index
    @projects = Project.all
  end

  def show
    @project = Project.find_by_name!(params[:id])
    @builds = @project.builds.order('id desc').limit(20)

    respond_to do |format|
      format.html
      format.rss
    end
  end

  # GET /XmlStatusReport.aspx
  #
  # This action returns the current build status for all of the projects in the system
  def status_report
    @projects = Project.all
  end
end
