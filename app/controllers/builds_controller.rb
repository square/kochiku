class BuildsController < ApplicationController
  def create
    Build.create!({:state => :partitioning}.merge(params[:build]))
    head :ok
  end
end
