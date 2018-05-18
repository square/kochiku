require 'json'
require 'net/http'

class BuildAttemptsController < ApplicationController

  def start
    @build_attempt = BuildAttempt.find(params[:id])

    respond_to do |format|
      if @build_attempt.aborted?
        format.json { render :json => @build_attempt }
      elsif @build_attempt.start!(params[:builder])
        @build_attempt.log_streamer_port = params[:logstreamer_port]
        @build_attempt.instance_type = params[:instance_type] if params[:instance_type].present?
        @build_attempt.save
        format.json { render :json => @build_attempt }
      else
        format.json { render :json => @build_attempt.errors, :status => :unprocessable_entity }
      end
    end
  end

  def finish
    @build_attempt = BuildAttempt.find(params[:id])

    respond_to do |format|
      if @build_attempt.finish!(params[:state])
        format.json { head :ok }
        format.html do
          redirect_to repository_build_part_url(@build_attempt.build_part.build_instance.repository,
                                                @build_attempt.build_part.build_instance,
                                                @build_attempt.build_part)
        end
      else
        format.json { render :json => @build_attempt.errors, :status => :unprocessable_entity }
      end
    end
  end

  # Redirects to the build_part page since we don't have a page for a single build attempt.
  # Added as a shortcut method to use when the IDs of the relation chain is not handy.
  def show
    @build_attempt = BuildAttempt.find(params[:id])

    redirect_to repository_build_part_url(
      @build_attempt.build_part.build_instance.repository,
      @build_attempt.build_part.build_instance,
      @build_attempt.build_part,
      anchor: helpers.dom_id(@build_attempt))
  end

  def stream_logs
    @build_attempt = BuildAttempt.find(params[:id])
    unless @build_attempt.log_streamer_port || @build_attempt.builder
      render plain: "No log streaming available for this build attempt", status: 404
    end

    # if full log has already been uploaded, redirect there
    if (stdout_log = @build_attempt.build_artifacts.stdout_log.try(:first))
      redirect_to stdout_log
      return
    end

    @build = @build_attempt.build_instance
    @repository = @build.repository
    @build_part = @build_attempt.build_part
  end

  # basically proxies request to the appropriate worker
  def stream_logs_chunk
    @build_attempt = BuildAttempt.find(params[:id])
    start = params.fetch(:start, 0)
    max_bytes = params.fetch(:maxBytes, 250000)

    port = @build_attempt.log_streamer_port
    builder = @build_attempt.builder
    if !port || !builder
      render json: {"error" => "No log streaming available for this build attempt"}, status: 500
      return
    end

    # logstreamer_base_url = "http://#{builder}:#{port}"

    http = Net::HTTP.new(builder, port)
    http.read_timeout = 5

    response = begin
                 http.get("/build_attempts/#{@build_attempt.id}/log/stdout.log?start=#{start}&maxBytes=#{max_bytes}")
               rescue
                 false
               end

    if !response || response.code !~ /^2/
      render json: {"error" => "unable to reach log streamer"}, status: 500
      return
    end

    output_json = JSON.parse(response.body)
    output_json['state'] = @build_attempt.state
    render json: output_json
  end
end
