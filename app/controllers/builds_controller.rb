require 'git_repo'

class BuildsController < ApplicationController
  before_action :load_repository, :only => [:show, :retry_partitioning, :rebuild_failed_parts, :request_build, :abort, :toggle_merge_on_success, :build_status, :modified_time]
  before_action only: [:show] do
    @build = Build.includes(build_parts: :build_attempts)
                  .joins(:branch_record).where('branches.repository_id' => @repository.id)
                  .find(params[:id])
    calculate_build_attempts_position(@build.build_attempts.where(state: :runnable))
    format_build_parts_position
  end

  include BuildAttemptsQueuePosition

  caches_action :show, cache_path: proc {
    updated_at = Build.select(:updated_at).find(params[:id]).updated_at
    {
      build_modified: [updated_at.to_i, @repository.updated_at.to_i].max,
      queue_position: Digest::SHA1.hexdigest(@build_attempts_rank.values.join(','))
    }
  }

  def show
    respond_to do |format|
      format.html
      format.json { render :json => @build, include: { build_parts: { methods: [:status] } } }
      format.png do
        # See http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.21
        headers['Expires'] = CGI.rfc1123_date(Time.now.utc)

        send_data(@build.to_png, :type => 'image/png', :disposition => 'inline')
      end
    end
  end

  # Public: Kickoff a build from the kochiku CLI script
  #
  # repo_url         - The remote url for the git repository
  # git_sha          - (optional) the SHA of the specific git commit the user is requesting to build
  # git_branch       - String name of the git branch to perform the build of. If
  #                    'git_sha' is not specified then it will use HEAD of the git branch.
  # merge_on_success - Bool. Request kochiku automatically merge the branch if the build succeeds.
  #
  def create
    merge_on_success = (params[:merge_on_success] || false)
    repository = Repository.lookup_by_url(params[:repo_url])
    unless repository
      raise ActiveRecord::RecordNotFound, "Repository for #{params[:repo_url]} not found"
    end

    if params[:git_sha].present?
      build = repository.build_for_commit(params[:git_sha])
      if build
        head :ok, :location => repository_build_url(repository, build)
        return
      end
    end

    branch = repository.branches.where(name: params[:git_branch]).first_or_create!

    ref_to_build = if params[:git_sha].present?
                     params[:git_sha]
                   else
                     repository.sha_for_branch(branch.name)
                   end

    build = branch.builds.build(ref: ref_to_build, state: :partitioning, merge_on_success: merge_on_success)

    if build.save
      head :ok, :location => repository_build_url(repository, build)
    else
      render :plain => build.errors.full_messages.join('\n'), :status => :unprocessable_entity
    end
  end

  def retry_partitioning
    @build = Build.joins(:branch_record).where('branches.repository_id' => @repository.id).find(params[:id])

    # This means there was an error with the partitioning job; redo it
    if @build.build_parts.empty?
      @build.update_attributes! :state => :partitioning, :error_details => nil
      @build.enqueue_partitioning_job
    end

    redirect_to [@repository, @build]
  end

  def rebuild_failed_parts
    @build = Build.includes(build_parts: :build_attempts)
                  .joins(:branch_record).where('branches.repository_id' => @repository.id)
                  .find(params[:id])
    @build.build_parts.failed_errored_or_aborted.each do |part|
      # There is an exceptional case in Kochiku where a build part's prior attempt may have
      # passed but the latest attempt failed. We do not want to rebuild those parts.
      part.rebuild! if part.unsuccessful?
    end
    @build.update_attributes! state: :running

    redirect_to [@repository, @build]
  end

  def abort
    @build = Build.joins(:branch_record).where('branches.repository_id' => @repository.id).find(params[:id])
    @build.abort!
    redirect_to repository_build_path(@repository, @build)
  end

  def toggle_merge_on_success
    @build = Build.joins(:branch_record).where('branches.repository_id' => @repository.id).find(params[:id])
    @build.update_attributes!(:merge_on_success => params[:merge_on_success])
    redirect_to repository_build_path(@repository, @build)
  end

  def build_status
    @build = Build.joins(:branch_record).where('branches.repository_id' => @repository.id).find(params[:id])
    respond_to do |format|
      format.json do
        render :json => @build
      end
    end
  end

  def modified_time
    updated_at = Build.joins(:branch_record).where('branches.repository_id' => @repository.id)
                      .find(params[:id]).updated_at
    respond_to do |format|
      format.json do
        render :json => updated_at
      end
    end
  end

  def build_redirect
    build_instance = Build.find(params[:id])
    redirect_to repository_build_path(build_instance.repository, build_instance)
  end

  def build_ref_redirect
    # search prefix so that entire git ref does not have to be provided.
    build_instance = Build.where("ref LIKE ?", "#{params[:ref]}%").first
    redirect_to repository_build_path(build_instance.repository, build_instance)
  end

  private

  def load_repository
    r_namespace, r_name = params[:repository_path].split('/')
    @repository = Repository.where(namespace: r_namespace, name: r_name).first!
  end

  def format_build_parts_position
    @build_parts_position = {}
    @build_attempts_rank.each do |build_attempt_id, position|
      next if position.nil?
      build_part_id = BuildAttempt.find(build_attempt_id).build_part.id
      if @build_parts_position[build_part_id].nil?
        @build_parts_position[build_part_id] = position
      elsif @build_parts_position[build_part_id] > position
        @build_parts_position[build_part_id] = position
      end
    end
  end
end
