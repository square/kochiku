class BuildArtifactsController < ApplicationController

  def create
    @build_artifact = BuildArtifact.new
    @build_artifact.build_attempt_id = params[:build_attempt_id]
    @build_artifact.log_file = params[:build_artifact].try(:[], :log_file)

    respond_to do |format|
      if @build_artifact.save
        format.xml  { head :created, :location => @build_artifact.log_file.url }
      else
        format.xml  { render :xml => @build_artifact.errors, :status => :unprocessable_entity }
      end
    end
  end

  # A redirect is preferable to direct linking if logs are stored remotely with expiring urls.
  def show
    build_artifact = BuildArtifact.find(params[:id])

    if params[:format] == 'text'
      render text: build_artifact.log_contents
    else
      redirect_to build_artifact.log_file.url
    end
  end
end
