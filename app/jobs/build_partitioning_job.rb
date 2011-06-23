class BuildPartitioningJob < JobBase
  @queue = :partition

  def initialize(build_id)
    @build = Build.find(build_id)
  end

  def perform
    # TODO: some error checking on the shell-outs

    GitRepo.inside_copy("web-cache", @build.sha) do
      build_info = YAML.load_file("config/ci/build.yml")
      @build.partition(build_info.values)
    end

  end
end
