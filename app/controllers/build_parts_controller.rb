class BuildPartsController < ApplicationController
  before_filter :load_project_build_and_part, :only => [:rebuild, :show, :modified_time]
  caches_action :show, :cache_path => proc { |c|
    { :modified => @build_part.updated_at.to_i }
  }

  def show
  end

  def rebuild
    begin
      @build_part.rebuild!
    rescue GitRepo::RefNotFoundError
      flash[:error] = "It appears the commit #{@build.ref} no longer exists."
    end

    redirect_to [@project, @build]
  end

  def modified_time
    respond_to do |format|
      format.json do
        render :json => @build_part.updated_at
      end
    end
  end

private

  def load_project_build_and_part
    @project = Project.find_by_name!(params[:project_id])
    @build = @project.builds.find(params[:build_id])
    @build_part = @build.build_parts.find(params[:id])
  end
end
