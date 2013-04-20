class ProjectsController < ApplicationController
  def index
    @projects = Project.find_all_by_name('web') | Project.all(:order => "name ASC")
  end

  def ci_projects
    @repositories = Repository.all
    @projects = Project.where(:name => @repositories.map(&:repository_name))
  end

  def show
    @project = Project.find_by_name!(params[:id])
    @build = @project.builds.build(:queue => "developer")
    @builds = @project.builds.order('id desc').limit(12).includes(:build_parts => [:last_attempt, :last_completed_attempt, :build_attempts]).reverse

    @build_parts = ActiveSupport::OrderedHash.new
    @builds.each do |build|
      build.build_parts.each do |build_part|
        paths = build_part.paths.first
        (@build_parts[paths] ||= Hash.new)[build] = build_part
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
  # This action returns the current build status for all of the projects in the system
  def status_report
    @projects = Project.all
  end
end
