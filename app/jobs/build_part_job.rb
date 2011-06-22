class BuildPartJob < JobBase
  attr_reader :build_part, :build
  def initialize(build_part_id)
    @build_part = BuildPart.find(build_part_id)
    @build = build_part.build
  end

  def perform
    setup(@build.sha)
    # TODO:
    # collect stdout, stderr, and any logs
    if tests_green?
      build_part.build_part_results.create(:result => :passed)
    else
      build_part.build_part_results.create(:result => :failed)
    end
  end

  def setup(sha)
  # TODO:
    # git fetch the cache
    # git clone the cache
    # move web.cucumber symlink
  end

  def tests_green?
    # run hacked up script/ci
  end

end
