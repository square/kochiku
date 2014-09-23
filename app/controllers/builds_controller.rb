require 'git_repo'

class BuildsController < ApplicationController
  before_filter :load_project, :only => [:show, :abort, :build_status, :toggle_merge_on_success, :rebuild_failed_parts, :retry_partitioning, :request_build, :modified_time]

  caches_action :show, :cache_path => proc { |c|
    updated_at = @project.builds.select(:updated_at).find(params[:id]).updated_at
    { :modified => updated_at.to_i }
  }

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

    if build
      if !build.new_record? || build.save
        head :ok, :location => project_build_url(build.project, build)
      else
        render :plain => build.errors.full_messages.join('\n'), :status => :unprocessable_entity
      end
    else
      # requested branch does not match project branch for Github request
      # FIXME handle this differently, probably with a rescue_from
      head :ok
    end
  end

  def retry_partitioning
    @build = @project.builds.find(params[:id])
    # This means there was an error with the partitioning job; redo it
    if @build.build_parts.empty? && @build.test_command.present?
      @build.enqueue_partitioning_job
      @build.update_attributes! :state => :partitioning, :error_details => nil
    end

    redirect_to [@project, @build]
  end

  def rebuild_failed_parts
    @build = @project.builds.includes(:build_parts => :build_attempts).find(params[:id])
    @build.build_parts.failed_errored_or_aborted.each do |part|
      # There is an exceptional case in Kochiku where a build part's prior attempt may have
      # passed but the latest attempt failed. We do not want to rebuild those parts.
      part.rebuild! if part.unsuccessful?
    end
    @build.update_attributes! state: :running

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
        begin
          sha = @project.repository.sha_for_branch(params[:build][:branch])
          build = project_build(params[:build][:branch], sha)
        rescue RemoteServer::RefDoesNotExist
          flash[:error] = "Error adding build! branch #{params[:build][:branch]} not found on remote server."
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

  def modified_time
    updated_at = @project.builds.select(:updated_at).find(params[:id]).updated_at
    respond_to do |format|
      format.json do
        render :json => updated_at
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
        repository = Repository.lookup_by_url(params[:repo_url])
        raise ActiveRecord::RecordNotFound, "Repository for #{params[:repo_url]} not found" unless repository
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
    payload = params.fetch('payload')
    sha1 = payload.fetch('after')

    requested_branch = payload.fetch('ref', '').split('/').last

    if @project.branch == requested_branch
      existing_build = @project.repository.build_for_commit(sha1)
      if existing_build
        existing_build
      else
        @project.builds.build(ref: sha1, state: :partitioning, branch: @project.branch)
      end
    end
  end

  def project_build(branch, ref)
    merge_on_success = params[:merge_on_success] || false
    if @project.main?
      ref = @project.repository.sha_for_branch("master")
      branch = "master"
    end

    existing_build = @project.repository.build_for_commit(ref)
    if existing_build
      existing_build
    else
      @project.builds.build(ref: ref,
                            state: :partitioning,
                            merge_on_success: merge_on_success,
                            branch: branch)
    end

  end
end
