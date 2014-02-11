# TODO: Combine this controller with PullRequestsController#build
class RepositoriesController < ApplicationController
  skip_before_filter :verify_authenticity_token, :only => [:build_ref]

  def create
    @repository = Repository.where(url: params[:repository][:url]).first_or_initialize
    if @repository.update_attributes(repository_params)
      @repository.projects.find_or_create_by(name: "#{@repository.repository_name}-pull_requests")
      project = @repository.projects.find_or_create_by(name: @repository.repository_name)
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
    if @repository.update_attributes(repository_params)
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

    # refChanges is provided by the standard Stash webhooks plugin
    # https://marketplace.atlassian.com/plugins/com.atlassian.stash.plugin.stash-web-post-receive-hooks-plugin
    # Query string parameters are provided for easy integrations, since it the
    # simplest to implement.
    changes = if params[:refChanges]
      params[:refChanges].map do |change|
        [
          change[:refId].gsub(/^refs\/heads\//,''),
          change[:toHash]
        ]
      end
    else
      [params.values_at(:ref, :sha)]
    end

    result = changes.map do |ref, sha|
      ensure_build(repository, ref, sha)
    end

    render json: {
      builds: result.map {|project, build| {
        id:        build.id,
        build_url: project_build_url(project, build)
      }}
    }
  end

  def ensure_build(repository, ref, sha)
    project_name = repository.repository_name
    project_name += '-pull_requests' unless ref == 'master'

    project = repository.projects.where(name: project_name).first_or_create

    build = if ref == 'master'
      project.ensure_master_build_exists(sha)
    else
      project.ensure_developer_build_exists(ref, sha)
    end

    [project, build]
  end

  private

  def repository_params
    params.require(:repository).
      permit(:url, :repository_name, :test_command, :command_flag, :timeout,
             :build_pull_requests, :run_ci, :on_green_update,
             :use_branches_on_green, :on_success_note, :on_success_script,
             :send_build_failure_email, :allows_kochiku_merges)
  end
end
