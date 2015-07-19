module Partitioner
  class Base
    def initialize(build, kochiku_yml)
      @build = build
      @kochiku_yml = kochiku_yml
    end

    def partitions
      [
        {
          'type' => 'test',
          'files' => ['no-manifest'],
          'queue' => @build.branch_record.convergence? ? 'ci' : 'developer',
          'retry_count' => 0
        }
      ]
    end

    def emails_for_commits_causing_failures
      {}
    end
  end
end
