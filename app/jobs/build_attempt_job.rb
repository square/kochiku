require 'rest-client'

class BuildAttemptJob < JobBase

  def initialize(build_attempt_id, build_kind, build_ref, test_files)
    @build_attempt_id = build_attempt_id
    @build_ref = build_ref
    @build_type = build_kind
    @test_files = test_files
  end

  def perform
    build_status = signal_build_is_starting
    return if build_status == :aborted

    GitRepo.inside_copy('web-cache', @build_ref) do
      result = run_tests(@build_kind, @test_files) ? :passed : :failed
      signal_build_is_finished(result)
      collect_artifacts(BuildStrategy.artifacts_glob)
    end
  end

  def collect_artifacts(artifacts_glob)
    artifact_upload_url = "http://#{Rails.application.config.master_host}/build_attempts/#{@build_attempt_id}/build_artifacts"

    Dir[*artifacts_glob].each do |path|
      if File.file?(path) && !File.zero?(path)
        Cocaine::CommandLine.new("gzip", path).run
        path += '.gz'

        payload = {:build_artifact => {:log_file => File.new(path)}}
        begin
          RestClient::Request.execute(:method => :post, :url => artifact_upload_url, :payload => payload, :headers => {:accept => :xml}, :timeout => 60 * 5)
        rescue RestClient::Exception => e
          Rails.logger.error("Upload of artifact (#{path}) failed: #{e.message}")
        end
      end
    end
  end

  def on_exception(e)
    signal_build_is_finished(:errored)
    raise e
  end

  private

  def hostname
    `hostname`.strip
  end

  def run_tests(build_kind, test_files)
    BuildStrategy.execute_build(build_kind, test_files)
  end

  def signal_build_is_starting
    build_start_url = "http://#{Rails.application.config.master_host}/build_attempts/#{@build_attempt_id}/start"

    begin
      result = RestClient::Request.execute(:method => :post, :url => build_start_url, :payload => {:builder => hostname}, :headers => {:accept => :json})
      JSON.parse(result)["build_attempt"]["state"].to_sym
    rescue RestClient::Exception => e
      Rails.logger.error("Start of build (#{@build_attempt_id}) failed: #{e.message}")
      raise
    end
  end

  def signal_build_is_finished(result)
    build_finish_url = "http://#{Rails.application.config.master_host}/build_attempts/#{@build_attempt_id}/finish"

    begin
      RestClient::Request.execute(:method => :post, :url => build_finish_url, :payload => {:state => result}, :headers => {:accept => :json})
    rescue RestClient::Exception => e
      Rails.logger.error("Finish of build (#{@build_attempt_id}) failed: #{e.message}")
      raise
    end
  end
end
