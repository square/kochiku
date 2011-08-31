class BuildsController < ApplicationController
  before_filter :load_project, :only => :show

  def show
    @build = @project.builds.find(params[:id], :include => {:build_parts => [:last_attempt, :build_attempts]})
  end

  def create
    build = make_build

    if build && build.save
      head :ok, :location => project_build_url(build.project, build)
    else
      head :ok
    end
  end

  # Used to request a developer build through the Web UI
  def request_build
    if developer_build.save
      flash[:message] = "Build added!"
    else
      flash[:error] = "Error adding build!"
    end
    redirect_to project_path(params[:project_id])
  end

private
  def make_build
    if params['payload']
      build_from_github
    elsif params['build']
      developer_build
    end
  end

  def load_project
    @project = Project.find_by_name!(params[:project_id])
  end

  def build_from_github
    load_project
    payload = params['payload']

    requested_branch = payload['ref'].split('/').last

    if @project.branch == requested_branch
      @project.builds.build(:state => :partitioning, :ref => payload['after'], :queue => :ci)
    end
  end

  def developer_build
    @project = Project.where(:name => params[:project_id]).first
    if !@project
      @project = Project.create!(:name => params[:project_id])
    end

    @project.builds.find_or_initialize_by_ref(params[:build][:ref], :state => :partitioning, :queue => :developer)
  end
end
