class BuildsController < ApplicationController
  before_filter :load_project, :only => :show

  def show
    @build = @project.builds.find(params[:id])
  end

  def create
    if params['payload']
      @build = create_build_from_github
    elsif params['build']
      @build = create_developer_build
    end

    if @build
      head :ok, :location => project_build_url(@build.project, @build)
    else
      head :ok
    end
  end

private
  def load_project
    @project = Project.find_by_name!(params[:project_id])
  end

  def create_build_from_github
    load_project
    payload = params['payload']

    requested_branch = payload['ref'].split('/').last

    if @project.branch == requested_branch
      @project.builds.create!(:state => :partitioning, :ref => payload['after'], :queue => :ci)
    end
  end

  def create_developer_build
    @project = Project.where(:name => params[:project_id]).first
    if !@project
      @project = Project.create!(:name => params[:project_id])
    end

    @project.builds.create!(:state => :partitioning, :ref => params[:build][:ref], :queue => :developer)
  end
end
