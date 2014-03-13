class BuildArtifactsController < ApplicationController
  skip_before_filter :verify_authenticity_token
  
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

  def show
    @project = Project.find_by_name!(params[:project_id])
    @build = @project.builds.find(params[:build_id])
    @build_part = @build.build_parts.find(params[:part_id])
    @build_artifact = BuildArtifact.find(params[:id])
    @log_output = @build_artifact.log_contents.gsub("\n", '<br />')
  end

  def handle_escaped(rawtext)
    ansi_escaped(h(rawtext), 128938214124).html_safe
  end
end
