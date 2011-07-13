require 'webrick'

class BuildPartJob < JobBase
  attr_reader :build_part_result, :build_part, :build

  def initialize(build_part_result_id)
    @build_part_result = BuildPartResult.find(build_part_result_id)
    @build_part = BuildPart.find(@build_part_result.build_part_id)
    @build = @build_part.build
  end

  def perform
    build_part_result.start!(hostname)
    GitRepo.inside_copy('web-cache', build.sha, true) do
      result = tests_green? ? :passed : :failed
      build_part_result.finish!(result)
      collect_artifacts(build_part.artifacts_glob)
    end
  end

  def tests_green?
    ENV["TEST_RUNNER"] = build_part.kind
    ENV["RUN_LIST"] = build_part.paths.join(",")
    build_part.execute
  end

  def collect_artifacts(artifacts_glob)
    Dir[*artifacts_glob].each do |path|
      if File.file? path
        build_part_result.build_artifacts.create!(:log_file => File.open(path))
      end
    end
  end

  def on_exception(e)
    build_part_result.error!
    raise e
  end

  private
  def hostname
    `hostname`.strip
  end
end
