class RepositoriesController < ApplicationController
  skip_before_filter :verify_authenticity_token, :only => [:build_ref]

  def create
    repository = Repository.find_or_initialize_by_url(params[:repository][:url])
    repository.update_attributes!(params[:repository])
    repository.projects.find_or_create_by_name("#{repository.repository_name}-pull_requests")
    project = repository.projects.find_or_create_by_name(repository.repository_name)
    redirect_to project_url(project)
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
    repository = Repository.find(params[:id])
    repository.update_attributes!(params[:repository])
    redirect_to edit_repository_url(repository)
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

    project = repository.projects.find_or_create_by_name(project_name)

    build = if ref == 'master'
      project.ensure_master_build_exists(sha)
    else
      project.ensure_developer_build_exists(ref, sha)
    end

    render json: {
      build_url: project_build_url(project, build)
    }
  end
end
