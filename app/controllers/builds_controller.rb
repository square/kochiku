class BuildsController < ApplicationController
  def index
    @builds = Build.order('id desc').limit(20)

    respond_to do |format|
      format.html
      format.rss
    end
  end

  def show
    @build = Build.find(params[:id])
  end

  def create
    Build.build_sha!(params[:build])
    respond_to do |format|
      format.json {head :ok}
      format.html {redirect_to root_path}
    end
  end

end
