class BuildPartsController < ApplicationController
  before_filter :load_project_build_and_part, :only => [:rebuild, :show]

  def show
    respond_to do |format|
      format.json { render :json => @build_part.as_json.merge!(:last_build_attempt => last_attempt.as_json) }
      format.html {}
    end
  end

  def rebuild
    @build_part.rebuild!
    redirect_to [@project, @build]
  end

private

  def last_attempt
    @build_part.last_attempt
  end

  def load_project_build_and_part
    @project = Project.find_by_name!(params[:project_id])
    @build = @project.builds.find(params[:build_id])
    @build_part = @build.build_parts.find(params[:id])
  end
end
