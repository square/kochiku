class ProjectsController < ApplicationController
  # GET /XmlStatusReport.aspx
  #
  # This action returns the current build status for all of the projects in the system
  def status_report
    @projects = Project.all
  end

  # POST /projects/:name/push_receive_hook
  def push_receive_hook
    payload = params['payload']
    branch = payload['ref'].split('/').last
    project = Project.where(:name => params[:id], :branch => branch).first

    if project
      project.builds.create!(:state => :partitioning, :sha => payload['after'], :queue => "master")
    end
    head :ok
  end
end
