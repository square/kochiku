class BranchesController < ApplicationController
  caches_action :show, :cache_path => proc { |c|
    updated_at = Branch.where(:name => params[:id]).select(:updated_at).first!.updated_at
    { :modified => updated_at.to_i }
  }

  # lists all of the branches for a repository
  def index
    load_repository
    @branches = @repository.branches
  end

  def show
    load_repository_and_branch
    @build = @branch.builds.build
    @builds = @branch.builds.includes(build_parts: :build_attempts).last(12)
    @current_build = @builds.last

    @build_parts = Hash.new
    @builds.reverse_each do |build|
      build.build_parts.each do |build_part|
        key = [build_part.paths.first, build_part.kind, build_part.options['ruby']]
        (@build_parts[key] ||= Hash.new)[build] = build_part
      end
    end

    if params[:format] == 'rss'
      # remove recent builds that are pending or in progress (cimonitor expects this)
      @builds = @builds.drop_while {|build| [:partitioning, :runnable, :running].include?(build.state) }
    end

    @branch = @branch.decorate

    respond_to do |format|
      format.html
      # Note: appending .rss to the end of the url will not return RSS format
      # due to the very permissive branch id constraint. Instead users will
      # have to specify a query param of format=rss to receive the RSS feed.
      format.rss { @builds = @builds.reverse } # most recent first
    end
  end

  def request_new_build
    load_repository_and_branch

    ref = @repository.sha_for_branch(@branch.name)

    existing_build = @repository.build_for_commit(ref)

    if existing_build.present?
      flash[:warn] = "Did not find a new commit on the #{@branch.name} branch to build"
      redirect_to repository_branch_path(@repository, @branch)
    else
      build = @branch.builds.build(ref: ref, state: :partitioning)

      if build.save
        flash[:message] = "New build started for #{build.ref} on #{@branch.name}"
        redirect_to repository_build_path(@repository, build)
      else
        flash[:error] = "Error adding build! #{build.errors.full_messages.to_sentence}"
        redirect_to repository_branch_path(@repository, @branch)
      end
    end
  end

  def health
    load_repository_and_branch

    @builds = @branch.builds.includes(:build_parts => :build_attempts).last(params[:count] || 12)

    build_part_attempts = Hash.new(0)
    build_part_failures = Hash.new(0)
    failed_parts = Hash.new
    @builds.each do |build|
      build.build_parts.each do |build_part|
        key = [build_part.paths.sort, build_part.kind]
        build_part.build_attempts.each do |build_attempt|
          if build_attempt.successful?
            build_part_attempts[key] = build_part_attempts[key] + 1
          elsif build_attempt.unsuccessful?
            build_part_attempts[key] = build_part_attempts[key] + 1
            build_part_failures[key] = build_part_failures[key] + 1
            failed_parts[key] = (failed_parts[key] || []) << build_part
          end
        end
      end
    end

    @part_climate = Hash.new
    failed_parts.each do |key, parts|
      part_error_rate = (build_part_failures[key] * 100 / build_part_attempts[key])
      @part_climate[[part_error_rate, key]] = parts.uniq
    end

    @branch = @branch.decorate
  end

  def build_time_history
    load_repository_and_branch

    history_json = Rails.cache.fetch("build-time-history-#{@branch.id}-#{@branch.updated_at}") do
      @branch.decorate.build_time_history.to_json
    end

    respond_to do |format|
      format.json do
        render :json => history_json
      end
    end
  end

  # GET /XmlStatusReport.aspx
  #
  # This action returns the current build status for all of the master branches
  # in the system
  def status_report
    @branches = Branch.includes(:repository).where(name: 'master').decorate
  end

  private

  def load_repository
    r_namespace, r_name = params[:repository_path].split('/')
    @repository = Repository.where(namespace: r_namespace, name: r_name).first!
  end

  def load_repository_and_branch
    @repository || load_repository
    @branch = @repository.branches.where(name: params[:id]).first!
  end
end
