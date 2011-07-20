class BuildPartsController < ApplicationController
  before_filter :load_project_build_and_part, :only => [:rebuild, :show]

  def show
  end

  def rebuild
    @build_part.rebuild!
    redirect_to [@project, @build]
  end

private

  def load_project_build_and_part
    @project = Project.find_by_name!(params[:project_id])
    @build = @project.builds.find(params[:build_id])
    @build_part = @build.build_parts.find(params[:id])
  end
end
