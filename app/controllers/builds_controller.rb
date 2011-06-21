class BuildsController < ApplicationController
  def create
    Build.create!({:state => :preparing}.merge(params[:build]))
    head :ok
  end
end
