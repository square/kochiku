require 'partitioner/default'
require 'git_blame'

module Partitioner
  # A variation on Partitioner::Default, which allows builds to run a subset of tests based on the files changed
  # on its branch.
  #
  # Accepts all the same configuration options as Partitioner::Default, and optionally accepts a dependency_map for
  # each specified test target.
  #
  # Sample excerpt from `kochiku.yml` with options:
  #
  # ```yml
  # partitioner: dependency_map
  #
  # dependency_map_options:
  #   # Branches with these names will include files that match every test_glob, regardless of files changed on branch
  #   run_all_tests_for_branches:
  #     - master
  #
  # targets:
  #   - dependency_map:
  #       # For each object in the dependency_map array, if its source_glob matches files changed on this branch,
  #       # add files that match its test_glob to the files that should be used in the partitions
  #       - source_glob: foo/**
  #         test_glob: foo/**/*spec.rb
  #         workers: 1  # Add this many workers if this source_glob matches files changed on this branch
  #
  #       - source_glob:
  #           - bar/**
  #           - app/bar/**
  #         test_glob:
  #           - bar/**/*spec.rb
  #           - spec/bar/**/*spec.rb
  #         workers: 5
  #
  #       - source_glob: *
  #         test_glob: baz/*spec.rb
  #
  #     # If a target specifies a default_test_glob and none of its specified source_globs match files changed,
  #     # add files that match its default_test_glob to the files that should be used in the partitions
  #     default_test_glob:
  #       - {foo,bar}/**/*spec.rb
  #       - spec/bar/**/*spec.rb
  #       - baz/*spec.rb
  #
  #     # Maximum number of workers for this partition
  #     workers: 30
  # ```
  class DependencyMap < Default
    private

    KOCHIKU_YML_LOCS = %w(kochiku.yml config/kochiku.yml config/ci/kochiku.yml).freeze

    # Indicates whether this build should run all test files, or only those test files which map to source files
    # that have changed in this branch
    def should_run_all_tests
      @should_run_all_tests ||= (
        # TODO(WFE-1190): Re-enable logic to run all tests if kochiku.yml has changed
        # Run all tests if kochiku.yml file was changed in this branch
        # changed_files = GitBlame.net_files_changed_in_branch(@build).map { |file_object| file_object[:file] }
        # return true unless (changed_files & KOCHIKU_YML_LOCS).empty?

        # Run all tests if kochiku.yml is formatted the old way (as an array)
        return true if @kochiku_yml.is_a?(Array)

        # Run all tests if this branch name is included in dependency_map_options.run_all_tests_for_branches
        branches_that_run_all_tests = @kochiku_yml
                                      .fetch('dependency_map_options', {})
                                      .fetch('run_all_tests_for_branches', [])

        [*branches_that_run_all_tests].include?(@build.branch_record.name)
      )
    end

    # Overrides Partitioner::Default#get_file_parts_for. Decides which test files to include in the partitions
    # based on dependency_map option in each test target.
    def get_file_parts_for(subset)
      glob = subset.fetch('glob', '/dev/null')
      manifest = subset['manifest']
      workers = subset.fetch('workers', 1)

      strategy = subset.fetch('balance', 'round_robin')
      strategy = 'round_robin' unless Strategies.respond_to?(strategy) # override if specified strategy is invalid

      dependency_map = subset['dependency_map']
      default_test_glob = subset['default_test_glob']

      if dependency_map.present?
        if should_run_all_tests
          test_globs_to_add = dependency_map.map { |dependency| dependency.fetch('test_glob', '') } << default_test_glob
        else
          test_globs_to_add = []
          workers_for_dependency_map = 0

          changed_files = GitBlame.net_files_changed_in_branch(@build).map { |file_object| file_object[:file] }

          # If a source_glob matches the changed files on this branch, add its test_glob to the partition
          dependency_map.each do |dependency|
            source_globs = [*dependency.fetch('source_glob', '')]

            matched_files = changed_files.select { |path| source_globs.any? { |pattern| File.fnmatch(pattern, path) } }

            unless matched_files.empty?
              test_globs_to_add << dependency.fetch('test_glob', '')
              workers_for_dependency_map += dependency.fetch('workers', 0)
            end
          end

          # If no source_globs matched the changed files on this branch, add the default_test_glob to the partition
          if test_globs_to_add.empty?
            test_globs_to_add << default_test_glob
          end

          # If workers were added for the source_globs that matched, and the total is less than the maximum number
          # of workers allotted for this target, use that amount of workers to build the partitions
          if workers_for_dependency_map > 0
            workers = [workers, workers_for_dependency_map].min
          end
        end

        test_globs_to_add.flatten!
        files = Dir[*test_globs_to_add]
      elsif default_test_glob.present?
        files = Dir[*default_test_glob]
      else
        files = Array(load_manifest(manifest)) | Dir[*glob]
      end

      file_to_times_hash = load_manifest(subset['time_manifest'])

      balanced_partitions = if file_to_times_hash.is_a?(Hash)
                              @max_time ||= max_build_time
                              time_greedy_partitions_for(file_to_times_hash, files, workers)
                            else
                              []
                            end

      files -= balanced_partitions.flatten

      Strategies.send(strategy, files, workers) + balanced_partitions
    end
  end
end
