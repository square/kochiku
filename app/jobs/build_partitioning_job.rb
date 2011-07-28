class BuildPartitioningJob < JobBase
  @queue = :partition

  def initialize(build_id)
    @build = Build.find(build_id)
  end

  def perform
    GitRepo.inside_copy("web-cache", @build.ref) do
      build_info = YAML.load_file("config/ci/build.yml")
      @build.partition(build_info.values.select {|part| part['type']})
    end
  end

  def on_exception(e)
    @build.update_attributes!(:state => :error)
    super
  end
end
