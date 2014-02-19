class ProjectsController < ApplicationController
  def index
    @projects = Project.order("name ASC")
  end

  def ci_projects
    @repositories = Repository.select(:repository_name)
    @projects = Project.includes(:repository).where(:name => @repositories.map(&:repository_name))
  end

  def show
    @project = Project.find_by_name!(params[:id])
    @build = @project.builds.build
    @builds = @project.builds.includes(build_parts: :build_attempts).last(12)
    @current_build = @builds.last

    @build_parts = ActiveSupport::OrderedHash.new
    @builds.reverse.each do |build|
      build.build_parts.each do |build_part|
        key = [build_part.paths.first, build_part.kind, build_part.options['ruby']]
        (@build_parts[key] ||= Hash.new)[build] = build_part
      end
    end

    if params[:format] == 'rss'
      # remove recent builds that are pending or in progress (cimonitor expects this)
      @builds = @builds.drop_while {|build| [:partitioning, :runnable, :running].include?(build.state) }
    end

    respond_to do |format|
      format.html
      format.rss { @builds = @builds.reverse } # latest first
    end
  end

  def build_time_history
    @project = Project.find_by_name!(params[:project_id])

    respond_to do |format|
      format.json do
        render :json => @project.build_time_history
      end
    end
  end

  # GET /XmlStatusReport.aspx
  #
  # This action returns the current build status for all of the main projects in the system
  def status_report
    @projects = Repository.all.map { |repo|
      Project.where(:repository_id => repo.id, :name => repo.repository_name).first
    }.compact
  end
end
