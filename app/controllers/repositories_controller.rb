# TODO: Combine this controller with PullRequestsController#build
class RepositoriesController < ApplicationController
  skip_before_filter :verify_authenticity_token, :only => [:build_ref]

  def create
    if params.fetch(:repository)[:url].blank?
      redirect_to new_repository_path, error: "Missing required value: Repository URL"
      return
    end

    @repository = Repository.new(repository_params)
    if @repository.save
      # create two initial projects; one for ci on the master branch, and one for pull-requests
      @repository.projects.find_or_create_by(name: "#{@repository.name}-pull_requests")
      project = @repository.projects.find_or_create_by(name: @repository.name)
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
    @repository.run_ci = true
  end

  def destroy
    Repository.find(params[:id]).destroy
    redirect_to repositories_path
  end

  def update
    @repository = Repository.find(params[:id])
    if @repository.update_attributes(repository_params)
      flash[:message] = "Settings updated."
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

  def ensure_build(repository, branch, sha)
    project_name = repository.name
    project_name += '-pull_requests' unless branch == 'master'

    project = repository.projects.where(name: project_name).first_or_create

    build = if branch == 'master'
      project.ensure_master_build_exists(sha)
    else
      project.ensure_branch_build_exists(branch, sha)
    end

    [project, build]
  end

  private

  def repository_params
    params.require(:repository).
      permit(:url, :name, :test_command, :timeout,
             :build_pull_requests, :run_ci, :on_green_update,
             :on_success_note, :on_success_script,
             :send_build_failure_email, :allows_kochiku_merges)
  end
end
