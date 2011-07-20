require 'rest-client'

class BuildPartJob < JobBase

  def initialize(build_attempt_id)
    @build_attempt = BuildAttempt.find(build_attempt_id)
    @build_part = @build_attempt.build_part
    @build = @build_part.build_instance
  end

  def perform
    @build_attempt.start!(hostname)
    GitRepo.inside_copy('web-cache', @build.sha, true) do
      result = tests_green? ? :passed : :failed
      @build_attempt.finish!(result)
      collect_artifacts(@build_part.artifacts_glob)
    end
  end

  def tests_green?
    ENV["TEST_RUNNER"] = @build_part.kind
    ENV["RUN_LIST"] = @build_part.paths.join(",")
    @build_part.execute
  end

  def collect_artifacts(artifacts_glob)
    Dir[*artifacts_glob].each do |path|
      if File.file?(path) && !File.zero?(path)
        RestClient.post "http://#{Rails.application.config.master_host}/build_attempts/#{@build_attempt.id}/build_artifacts", :build_artifact => {:log_file => File.open(path)}, :accept => :xml
      end
    end
  end

  def on_exception(e)
    @build_attempt.error!
    raise e
  end

  private
  def hostname
    `hostname`.strip
  end
end
