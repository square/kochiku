class BuildAttemptsController < ApplicationController
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
      else
        format.json  { render :json => @build_attempt.errors, :status => :unprocessable_entity }
      end
    end
  end
end
