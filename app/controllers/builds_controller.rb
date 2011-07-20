class BuildsController < ApplicationController
  before_filter :load_project

  def show
    @build = @project.builds.find(params[:id])
  end

  def create
    payload = params['payload']

    requested_branch = payload['ref'].split('/').last

    if @project.branch == requested_branch
      @project.builds.create!(:state => :partitioning, :sha => payload['after'], :queue => "master")
    end
    head :ok
  end

private
  def load_project
    @project = Project.find_by_name!(params[:project_id])
  end
end
