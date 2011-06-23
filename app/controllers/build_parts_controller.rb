class BuildPartsController < ApplicationController
  def rebuild
    build = Build.find params[:build_id]
    build_part = build.build_parts.find params[:id]
    build_part.enqueue_build_part_job
    redirect_to build
  end
end
