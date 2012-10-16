class RepositoriesController < ApplicationController
  def create
    repository = Repository.find_or_initialize_by_url(params[:repository][:url])
    repository.update_attributes!(params[:repository])
    project = repository.projects.find_or_create_by_name("#{repository.repository_name}-pull_requests")
    project = repository.projects.find_or_create_by_name(repository.repository_name)
    redirect_to project_url(project)
  end

  def new
    @repository = Repository.new
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
end
