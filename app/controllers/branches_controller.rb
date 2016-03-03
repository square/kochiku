class BranchesController < ApplicationController
  caches_action :show, cache_path: proc {
    load_repository_and_branch
    updated_at = @branch.updated_at
    { :modified => updated_at.to_i }
  }

  caches_action :status_report, expires_in: 15.seconds

  # lists all convergence branches as well the 100 most recently active
  # branches
  def index
    load_repository
    @convergence_branches = @repository.branches.where(convergence: true)
    @recently_active_branches = @repository.branches.where(convergence: false).order('updated_at DESC').limit(100)
  end

  def show
    load_repository_and_branch
    @build = @branch.builds.build
    @builds = @branch.builds.includes(build_parts: :build_attempts).last(12)
    @current_build = @builds.last

    @build_parts = {}
    @builds.reverse_each do |build|
      build.build_parts.each do |build_part|
        key = [build_part.paths.first, build_part.kind, build_part.options['ruby']]
        (@build_parts[key] ||= {})[build] = build_part
      end
    end

    @branch = @branch.decorate

    respond_to do |format|
      format.html
      # Note: appending .rss to the end of the url will not return RSS format
      # due to the very permissive branch id constraint. Instead users will
      # have to specify a query param of format=rss to receive the RSS feed.
      format.rss { @builds = @builds.reverse } # most recent first
      format.json
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
    initialize_stats_variables
    load_build_stats

    @builds = @branch.builds.includes(:build_parts => :build_attempts).last(params[:count] || 12)

    build_part_attempts = Hash.new(0)
    build_part_failures = Hash.new(0)
    failed_parts = {}
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

    @part_climate = {}
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
  # This action returns the current build status for all of the convergence branches
  # in the system
  def status_report
    @branches = Branch.includes(:repository).where(convergence: true).decorate
  end

  private

  def load_repository
    r_namespace, r_name = params[:repository_path].split('/')
    @repository = Repository.where(namespace: r_namespace, name: r_name).first!
  end

  def load_repository_and_branch
    @repository || load_repository
    @branch ||= @repository.branches.where(name: params[:id]).first!
  end

  # set the various stats variables to reasonable null values in case
  # the load_build_stats method short-circuits
  def initialize_stats_variables
    @days_since_first_build = 0
    @total_build_count = 0
    @total_failure_count = 0
    @total_pass_rate = '—'
    @last30_build_count = 0
    @last30_failure_count = 0
    @last30_pass_rate = '—'
    @last7_build_count = 0
    @last7_failure_count = 0
    @last7_pass_rate = '—'
  end

  def load_build_stats
    @first_built_date = @branch.builds.first.try(:created_at)
    return if @first_built_date.nil?

    @days_since_first_build = (Date.today - @first_built_date.to_date).to_i

    @total_build_count = @branch.builds.count
    @total_failure_count = @branch.builds.where.not(state: 'succeeded').count
    @total_pass_rate = (@total_build_count - @total_failure_count) * 100 / @total_build_count

    @last30_build_count = @branch.builds.where('created_at >= ?', Date.today - 30.days).count
    return if @last30_build_count.zero?
    @last30_failure_count = @last30_build_count - @branch.builds.where('state = "succeeded" AND created_at >= ?', Date.today - 30.days).count
    @last30_pass_rate = (@last30_build_count - @last30_failure_count) * 100 / @last30_build_count

    @last7_build_count = @branch.builds.where('created_at >= ?', Date.today - 7.days).count
    return if @last7_build_count.zero?
    @last7_failure_count = @last7_build_count - @branch.builds.where('state = "succeeded" AND created_at >= ?', Date.today - 7.days).count
    @last7_pass_rate = (@last7_build_count - @last7_failure_count) * 100 / @last7_build_count
  end
end
