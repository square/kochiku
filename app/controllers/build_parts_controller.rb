class BuildPartsController < ApplicationController
  before_action :load_repository_build_and_part, :only => [:rebuild, :show, :modified_time]

  caches_action :show, cache_path: proc {
    { :modified => [@build_part.updated_at.to_i, @repository.updated_at.to_i].max }
  }

  def show
    respond_to do |format|
      format.html
      format.json do
        render :json => @build_part, include: { build_attempts: { include: :build_artifacts } }
      end
    end
  end

  def rebuild
    begin
      @build_part.rebuild!
    rescue GitRepo::RefNotFoundError
      flash[:error] = "It appears the commit #{@build.ref} no longer exists."
    end

    redirect_to [@repository, @build]
  end

  def modified_time
    respond_to do |format|
      format.json do
        render :json => @build_part.updated_at
      end
    end
  end

  private

  def load_repository_build_and_part
    r_namespace, r_name = params[:repository_path].split('/')
    @repository = Repository.where(namespace: r_namespace, name: r_name).first!
    @build = Build.joins(:branch_record).where('branches.repository_id' => @repository.id).find(params[:build_id])
    @build_part = @build.build_parts.find(params[:id])
  end
end
