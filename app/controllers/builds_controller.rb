class BuildsController < ApplicationController
  def create
    build = Build.create!({:state => :partitioning}.merge(params[:build]))
    Resque.enqueue(BuildPartitioningJob, build.id)
    head :ok
  end
end
