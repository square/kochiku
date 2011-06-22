class BuildPartJob < JobBase
  def initialize(build_part_id)
    @build_part = BuildPart.find(build_part_id)
  end

  def perform
    # TODO:
    # git fetch the cache
    # git clone the cache
    # move web.cucumber symlink
    # [probably] sighup nginx


    # git pull (whatever cruise does)
    # run hacked up script/ci
    # collect stdout, stderr, and any logs
    # set result
    @build_part.build_part_results.create!(:result => :passed)
  end
end
