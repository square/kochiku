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
                                                          @build_attempt.build_part) }
      else
        format.json  { render :json => @build_attempt.errors, :status => :unprocessable_entity }
      end
    end
  end

  # Redirects to the show page for the build_attempt's build_part. Added as a
  # shortcut method to use when the IDs of the relation chain is not handy.
  def build_part
    @build_attempt = BuildAttempt.find(params[:id])

    redirect_to project_build_part_path(
      @build_attempt.build_part.build_instance.project,
      @build_attempt.build_part.build_instance,
      @build_attempt.build_part)
  end
end
