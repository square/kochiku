class BuildPartsController < ApplicationController
  before_filter :load_build_and_part, :only => [:rebuild, :show]
  def rebuild
    @build_part.rebuild!
    redirect_to @build
  end

  def show
  end

  def load_build_and_part
    @build = Build.find params[:build_id]
    @build_part = @build.build_parts.find params[:id]
  end
end
