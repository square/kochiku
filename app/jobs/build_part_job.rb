class BuildPartJob < JobBase
  WORKING_DIR="#{Rails.root}/tmp/build-partition"

  attr_reader :build_part, :build

  def initialize(build_part_id)
    @build_part = BuildPart.find(build_part_id)
    @build = build_part.build
  end

  def perform
    tmp_dir_for(build.sha) do |working_directory|
      # TODO:
      # collect stdout, stderr, and any logs
      if tests_green?(working_directory)
        build_part.build_part_results.create(:result => :passed)
      else
        build_part.build_part_results.create(:result => :failed)
      end
    end
  end

  # TODO: refactor me. DRY.
  def tmp_dir_for(sha)
    # update local repo
    `cd #{WORKING_DIR}/web-cache && git fetch`

    Dir.mktmpdir(nil, WORKING_DIR) do |dir|
      # clone local repo (fast!)
      `cd #{dir} && git clone #{WORKING_DIR}/web-cache .`

      # checkout
      `cd #{dir} && git co #{sha}`

      yield(dir)
    end
  end

  def tests_green?(working_directory)
    ENV["TEST_RUNNER"] = build.kind
    ENV["RUN_LIST"] = build_part.paths.join(",")
    `cd #{working_directory} && script/ci worker`
    $? == 0
  end

end
