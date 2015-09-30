class RepositoriesController < ApplicationController

  def create
    if params.fetch(:repository)[:url].blank?
      redirect_to new_repository_path, error: "Missing required value: Repository URL"
      return
    end

    @repository = Repository.new(repository_params)

    # persist the repository and then create initial Branch records for the
    # convergence branches
    if @repository.save && update_convergence_branches
      redirect_to repository_branches_path(@repository)
    else
      @current_convergence_branches = params.fetch(:convergence_branches, "").split(',')
      render template: 'repositories/new'
    end
  end

  def new
    @repository = Repository.new
    @repository.run_ci = true
    @current_convergence_branches = ['master']
  end

  def destroy
    ActiveRecord::Base.no_touching do
      Repository.destroy(params[:id])
    end
    redirect_to repositories_path
  end

  def update
    @repository = Repository.find(params[:id])

    if @repository.update_attributes(repository_params) && update_convergence_branches
      flash[:message] = "Settings updated."
      redirect_to repository_edit_url(@repository)
    else
      @current_convergence_branches = params.fetch(:convergence_branches, "").split(',')
      render template: 'repositories/edit'
    end
  end

  def edit
    r_namespace, r_name = params[:repository_path].split('/')
    @repository = Repository.where(namespace: r_namespace, name: r_name).first!

    @current_convergence_branches = @repository.branches.where(convergence: true).select(:name).collect(&:name)
  end

  def index
    @repositories = Repository.all
  end

  def dashboard
    @branches =
      Branch.joins(:repository)
      .includes(:repository)
      .where(name: 'master')
      .order('repositories.name')
      .decorate
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
      builds: result.map { |build|
        {
          id:        build.id,
          build_url: repository_build_url(repository, build)
        }
      }
    }
  end

  def ensure_build(repository, branch_name, sha)
    branch = repository.branches.where(name: branch_name).first_or_create!

    build = repository.ensure_build_exists(sha, branch)
    branch.abort_in_progress_builds_behind_build(build) if !branch.convergence?

    build
  end

  private

  def repository_params
    params.require(:repository)
      .permit(:url, :timeout, :build_pull_requests,
              :run_ci, :on_green_update, :send_build_success_email,
              :send_build_failure_email, :allows_kochiku_merges,
              :email_on_first_failure, :send_merge_successful_email)
  end

  # update_convergence_branches is called by both create and update. This
  # method does more work than is necessary for create but it is used to avoid
  # duplicating code.
  def update_convergence_branches
    new_branch_names = params.fetch(:convergence_branches, "").split(',').map(&:strip)
    current_convergence_branches = @repository.branches.where(convergence: true).all
    current_branch_names = current_convergence_branches.collect(&:name)
    remove_convergence_from = current_branch_names - new_branch_names
    add_convergence_to = new_branch_names - current_branch_names

    remove_convergence_from.each do |name|
      current_convergence_branches.detect { |branch|
        branch.name == name
      }.update!(convergence: false)
    end

    add_convergence_to.each do |name|
      branch = @repository.branches.where(name: name).first_or_create!
      branch.update!(convergence: true)
    end
    true
  end
end
