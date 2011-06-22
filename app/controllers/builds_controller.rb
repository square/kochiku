class BuildsController < ApplicationController

  def index
    @builds = Build.order('id desc')
  end

  def create
    Build.build_sha!(params[:build])
    head :ok
  end
end
