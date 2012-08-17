class BuildAttemptsController < ApplicationController
  skip_before_filter :verify_authenticity_token

  def start
    @build_attempt = BuildAttempt.find(params[:id])

    respond_to do |format|
      if @build_attempt.aborted?
        format.json  { render :json => @build_attempt }
      elsif @build_attempt.start!(params[:builder])
        format.json  { render :json => @build_attempt }
      else
        format.json  { render :json => @build_attempt.errors, :status => :unprocessable_entity }
      end
    end
  end

  def finish
    @build_attempt = BuildAttempt.find(params[:id])

    respond_to do |format|
      if @build_attempt.finish!(params[:state])
        format.json  { head :ok }
        format.html  { redirect_to project_build_part_url(@build_attempt.build_part.project,
                                                          @build_attempt.build_part.build_instance,
                                                          @build_attempt) }
      else
        format.json  { render :json => @build_attempt.errors, :status => :unprocessable_entity }
      end
    end
  end
end
