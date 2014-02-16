require 'git_repo'

class BuildsController < ApplicationController
  before_filter :load_project, :only => [:show, :abort, :build_status, :toggle_merge_on_success, :rebuild_failed_parts, :request_build]
  skip_before_filter :verify_authenticity_token, :only => [:create]

  def show
    @build = @project.builds.includes(build_parts: :build_attempts).find(params[:id])

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
    @build = @project.builds.includes(:build_parts => :build_attempts).find(params[:id])
    @build.build_parts.failed_errored_or_aborted.each do |part|
      # There is an exceptional case in Kochiku where a build part's prior attempt may have
      # passed but the latest attempt failed. We do not want to rebuild those parts.
      part.rebuild! if part.unsuccessful?
    end
    @build.update_attributes state: :running

    redirect_to [@project, @build]
  end

  # Used to request a build through the Web UI
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
          flash[:error] = "Error adding build! branch #{params[:build][:branch]} not found on remote server."
        else
          build = project_build(params[:build][:branch], sha)
        end
      end
    end

    if build
      if build.new_record?
        if build.save
          flash[:message] = "Build added!"
          redirect_to project_build_path(params[:project_id], build)
          return
        else
          flash[:error] = "Error adding build! #{build.errors.full_messages.to_sentence}"
        end
      elsif @project.main?
        # did not find a newer revision on the main branch
        flash[:warn] = "Did not find a new commit on the master branch to build"
      else
        # did not find a new unbuilt commit. redirect to most recent build
        flash[:warn] = "#{build.ref[0...8]} is the most recent commit on #{params[:build][:branch]}"
        redirect_to project_build_path(params[:project_id], build)
        return
      end
    end

    redirect_to project_path(params[:project_id])
  end

  def abort
    @build = @project.builds.find(params[:id])
    @build.abort!
    redirect_to project_build_path(@project, @build)
  end

  def toggle_merge_on_success
    @build = @project.builds.find(params[:id])
    @build.update_attributes!(:merge_on_success => params[:merge_on_success])
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
        normalized_url = Repository.canonical_repository_url(params[:repo_url])
        repository = Repository.where(url: normalized_url).first_or_create!
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
      @project.builds.find_existing_build_or_initialize(payload['after'], :state => :partitioning)
    end
  end

  def project_build(branch, ref)
    merge_on_success = params[:merge_on_success] || false
    if @project.main?
      ref = GitRepo.sha_for_branch(@project.repository, "master")
      branch = "master"
    end
    @project.builds.find_existing_build_or_initialize(
      ref,
      :state => :partitioning,
      :merge_on_success => merge_on_success,
      :branch => branch)
  end
end
