require 'git_repo'

class BuildsController < ApplicationController
  before_filter :load_project, :only => [:show, :abort, :build_status, :abort_auto_merge, :rebuild_failed_parts]
  skip_before_filter :verify_authenticity_token, :only => [:create]

  def show
    @build = @project.builds.find(params[:id], :include => {:build_parts => [:last_attempt, :build_attempts]})

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

    redirect_to [@project, @build]
  end

  # Used to request a developer build through the Web UI
  def request_build
    if project_build.save
      flash[:message] = "Build added!"
    else
      flash[:error] = "Error adding build!"
    end
    redirect_to project_path(params[:project_id])
  end

  def abort
    @build = @project.builds.find(params[:id])
    @build.abort!
    redirect_to project_build_path(@project, @build)
  end

  def abort_auto_merge
    @build = @project.builds.find(params[:id])
    @build.update_attributes!(:auto_merge => false)
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
      project_build
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

  def project_build
    @project = Project.where(:name => params[:project_id]).first
    if !@project
      repository = Repository.find_or_create_by_url(params[:repo_url])
      @project = repository.projects.create!(:name => params[:project_id])
    end
    auto_merge = params[:auto_merge] || false
    branch = params[:build][:branch] if params[:build]
    queue = @project.main_build? ? :ci : :developer
    ref = params[:build][:ref] if params[:build]
    if queue == :ci
      ref = GitRepo.current_master_ref(@project.repository)
      branch = "master"
    end
    @project.builds.find_or_initialize_by_ref(ref, :state => :partitioning, :queue => queue, :auto_merge => auto_merge, :branch => branch)
  end
end
