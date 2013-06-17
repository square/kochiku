require 'git_repo'

class BuildsController < ApplicationController
  before_filter :load_project, :only => [:index, :show, :abort, :build_status, :toggle_auto_merge, :rebuild_failed_parts, :request_build]
  skip_before_filter :verify_authenticity_token, :only => [:create]

  def index
    @builds = @project.builds.order('id desc').limit(20)
    respond_to do |format|
      format.xml
    end
  end

  def show
    @build = @project.builds.find(params[:id], :include => {:build_parts => [:last_attempt, :last_completed_attempt, :build_attempts]})

    respond_to do |format|
      format.html
      format.png do
        # See http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.21
        headers['Expires'] = CGI.rfc1123_date(Time.now.utc)

        send_data(@build.to_png, :type => 'image/png', :disposition => 'inline')
      end
    end
  end

  def create
    build = make_build

    if build && build.save
      head :ok, :location => project_build_url(build.project, build)
    else
      head :ok
    end
  end

  def rebuild_failed_parts
    @build = @project.builds.find(params[:id], :include => {:build_parts => :build_attempts})
    @build.build_parts.failed_or_errored.each do |part|
      # There is an exceptional case in Kochiku where a build part's prior attempt may have
      # passed but the latest attempt failed. We do not want to rebuild those parts.
      part.rebuild! if part.unsuccessful?
    end
    @build.update_attributes state: :running

    redirect_to [@project, @build]
  end

  # Used to request a developer build through the Web UI
  def request_build
    build = nil

    if @project.main?
      build = project_build('master', 'HEAD') # Arguments ignored
    else
      unless params[:build] && params[:build][:branch].present?
        flash[:error] = "Error adding build! branch can't be blank"
      else
        sha = GitRepo.sha_for_branch(@project.repository, params[:build][:branch])
        if sha.nil?
          flash[:error] = "Error adding build! branch not found in Github"
        else
          build = project_build(params[:build][:branch], sha)
        end
      end
    end

    if build
      if build.save
        flash[:message] = "Build added!"
      else
        flash[:error] = "Error adding build! #{build.errors.full_messages.to_sentence}"
      end
    end

    redirect_to project_path(params[:project_id])
  end

  def abort
    @build = @project.builds.find(params[:id])
    @build.abort!
    redirect_to project_build_path(@project, @build)
  end

  def toggle_auto_merge
    @build = @project.builds.find(params[:id])
    @build.update_attributes!(:auto_merge => params[:auto_merge])
    redirect_to project_build_path(@project, @build)
  end

  def build_status
    @build = @project.builds.find(params[:id])
    respond_to do |format|
      format.json do
        render :json => @build
      end
    end
  end

  private

  def make_build
    if params['payload']
      build_from_github
    elsif params['build']
      @project = Project.where(:name => params[:project_id]).first
      unless @project
        repository = Repository.find_or_create_by_url(params[:repo_url])
        @project = repository.projects.create!(:name => params[:project_id])
      end
      project_build(params[:build][:branch], params[:build][:ref])
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
      queue = @project.main? ? :ci : :developer
      @project.builds.find_existing_build_or_initialize(payload['after'], :state => :partitioning, :queue => queue)
    end
  end

  def project_build(branch, ref)
    auto_merge = params[:auto_merge] || false
    queue = :developer
    if @project.main?
      queue = :ci
      ref = GitRepo.sha_for_branch(@project.repository, "master")
      branch = "master"
    end
    @project.builds.find_existing_build_or_initialize(ref, :state => :partitioning, :queue => queue, :auto_merge => auto_merge, :branch => branch)
  end
end
