class BuildArtifactsController < ApplicationController

  def show
    render :text => BuildArtifact.find(params[:id]).content
  end

end
