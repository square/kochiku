class RepositoriesController < ApplicationController
  skip_before_filter :verify_authenticity_token, :only => [:build_ref]

  def create
    @repository = Repository.where(url: params[:repository][:url]).first_or_initialize
    if @repository.update_attributes(params[:repository])
      @repository.projects.find_or_create_by_name("#{@repository.repository_name}-pull_requests")
      project = @repository.projects.find_or_create_by_name(@repository.repository_name)
      redirect_to project_url(project)
    else
      render template: 'repositories/new'
    end
  end

  def projects
    @projects = Project.where(:repository_id => params[:id])
    render :template => "projects/index"
  end

  def new
    @repository = Repository.new
  end

  def destroy
    Repository.find(params[:id]).destroy
    redirect_to repositories_path
  end

  def update
    @repository = Repository.find(params[:id])
    if @repository.update_attributes(params[:repository])
      redirect_to edit_repository_url(@repository)
    else
      render template: 'repositories/edit'
    end
  end

  def edit
    @repository = Repository.find(params[:id])
  end

  def index
    @repositories = Repository.all
  end

  def build_ref
    repository = Repository.find(params[:id])

    ref = params[:ref]
    sha = params[:sha]

    project_name = repository.repository_name
    project_name += '-pull_requests' unless ref == 'master'

    project = repository.projects.where(name: project_name).first_or_create

    build = if ref == 'master'
      project.ensure_master_build_exists(sha)
    else
      project.ensure_developer_build_exists(ref, sha)
    end

    render json: {
      id:        build.id,
      build_url: project_build_url(project, build)
    }
  end
end
