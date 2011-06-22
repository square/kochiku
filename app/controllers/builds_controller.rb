class BuildsController < ApplicationController

  def index
    @builds = Build.order('id desc')
  end

  def create
    Build.create!({:state => :partitioning}.merge(params[:build]))
    head :ok
  end
end
