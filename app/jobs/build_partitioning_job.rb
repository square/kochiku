class BuildPartitioningJob < JobBase
  WORKING_DIR="#{Rails.root}/tmp/build-partition"
  @queue = :partition

  def initialize(build_id)
    @build = Build.find(build_id)
  end

  def perform
    # TODO: some error checking on the shell-outs

    # update local repo
    `cd #{WORKING_DIR}/web-cache && git fetch`

    Dir.mktmpdir(nil, WORKING_DIR) do |dir|
      # clone local repo (fast!)
      `cd #{dir} && git clone #{WORKING_DIR}/web-cache .`

      # checkout
      `cd #{dir} && git co #{@build.sha}`
      build_info = YAML.load_file("#{dir}/config/ci/build.yml")

      @build.partition(build_info.values)
    end
  end

  def on_exception(e)
    @build.error!
    raise e
  end
end
