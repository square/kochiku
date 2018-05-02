class BuildPartsController < ApplicationController
  before_action :load_repository_build_and_part, only: [:rebuild, :show, :modified_time, :refresh_build_part_info]
  before_action only: [:show, :refresh_build_part_info] do
    calculate_build_attempts_position(@build_part.build_attempts, @build_part.queue)
  end

  include BuildAttemptsQueuePosition

  caches_action :show, cache_path: proc {
    {
      modified: [@build_part.updated_at.to_i, @repository.updated_at.to_i].max,
      queue_position: Digest::SHA1.hexdigest(@build_attempts_rank.values.join(','))
    }
  }

  def show
    respond_to do |format|
      format.html
      format.json do
        render :json => @build_part, include: { build_attempts: { methods: :files } }
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

  def refresh_build_part_info
    updates = []
    if @build_part.finished_at
      updates << { state: @build_part.status }
    else
      @build_part.build_attempts.each_with_index do |attempt, index|
        html = ApplicationController.render(partial: 'build_parts/build_attempts', locals: {  index: index,
                                                                                              attempt: attempt,
                                                                                              build_attempts_rank: @build_attempts_rank})
        updates << {id: index, content: html, state: @build_part.status}
      end
    end
    respond_to do |format|
      format.json do
        render :json => updates
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
