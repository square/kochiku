require 'rest-client'

class BuildAttemptJob < JobBase

  def initialize(build_attempt_id)
    @build_attempt = BuildAttempt.find(build_attempt_id)
    @build_part = @build_attempt.build_part
    @build = @build_part.build_instance
  end

  def perform
    @build_attempt.start!(hostname)
    GitRepo.inside_copy('web-cache', @build.ref) do
      result = tests_green? ? :passed : :failed
      @build_attempt.finish!(result)
      collect_artifacts(BuildStrategy.artifacts_glob)
    end
  end

  def tests_green?
    BuildStrategy.execute_build(@build_part)
  end

  def collect_artifacts(artifacts_glob)
    Dir[*artifacts_glob].each do |path|
      if File.file?(path) && !File.zero?(path)
        url = "http://#{Rails.application.config.master_host}/build_attempts/#{@build_attempt.id}/build_artifacts"
        payload = {:build_artifact => {:log_file => File.open(path)}}
        RestClient::Request.execute(:method => :post, :url => url, :payload => payload, :headers => {:accept => :xml}, :timeout => 60 * 5)
      end
    end
  end

  def on_exception(e)
    @build_attempt.error_occurred!
    raise e
  end

  private
  def hostname
    `hostname`.strip
  end
end
