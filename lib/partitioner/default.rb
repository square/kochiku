require 'partitioner/base'

module Partitioner
  # This is the origional partitioner behavior, which is somewhat ruby targeted
  class Default < Base
    def partitions
      GitRepo.inside_copy(@build.repository, @build.ref) do
        # Handle old kochiku.yml
        if @kochiku_yml.is_a?(Array)
          @kochiku_yml.map { |subset| partitions_for(subset) }.flatten
        else
          build_partitions
        end
      end
    end

    private

    def max_build_time
      if @kochiku_yml.is_a?(Array)
        @kochiku_yml
      else
        @kochiku_yml.fetch('targets')
      end.map do |subset|
        file_to_times_hash = load_manifest(subset['time_manifest'])
        file_to_times_hash.values if file_to_times_hash.is_a?(Hash)
      end.flatten.compact.max
    end

    def build_partitions
      if @kochiku_yml['ruby']
        @kochiku_yml['ruby'].flat_map do |ruby|
          build_targets(ruby)
        end
      else
        build_targets
      end
    end

    def build_targets(ruby_version=nil)
      options = {}
      options['ruby'] = ruby_version if ruby_version
      options['log_file_globs'] = Array(@kochiku_yml['log_file_globs']) if @kochiku_yml['log_file_globs']

      @kochiku_yml['targets'].flat_map do |subset|
        partitions_for(
          subset.merge('options' => options.clone)
        )
      end
    end

    def partitions_for(subset)
      glob = subset.fetch('glob', '/dev/null')
      type = subset.fetch('type', 'test')
      workers = subset.fetch('workers', 1)
      manifest = subset['manifest']
      retry_count = subset['retry_count'] || 0
      if subset['log_file_globs']
        subset['options']['log_file_globs'] = Array(subset['log_file_globs'])
      end

      queue = @build.branch_record.convergence? ? "ci" : "developer"
      queue_override = subset.fetch('queue_override', nil)
      queue = "#{queue}-#{queue_override}" if queue_override.present?

      strategy = subset.fetch('balance', 'round_robin')
      strategy = 'round_robin' unless Strategies.respond_to?(strategy) # override if specified strategy is invalid

      files = Array(load_manifest(manifest)) | Dir[*glob]

      file_to_times_hash = load_manifest(subset['time_manifest'])

      balanced_partitions = if file_to_times_hash.is_a?(Hash)
                              @max_time ||= max_build_time
                              time_greedy_partitions_for(file_to_times_hash, files, workers)
                            else
                              []
                            end

      files -= balanced_partitions.flatten

      (Strategies.send(strategy, files, workers) + balanced_partitions).map do |part_files|
        {'type' => type, 'files' => part_files.compact, 'queue' => queue,
         'retry_count' => retry_count, 'options' => subset['options']}
      end.select { |p| p['files'].present? }
    end

    # Balance tests by putting each test into the worker with the shortest expected execution time
    # If a test that no longer exists is referenced in the file_to_times_hash, do not include it in
    # the list of tests to be executed.  If there are new tests not included in the file_to_times_hash,
    # assume they will run fast.
    def time_greedy_partitions_for(file_to_times_hash, all_files, workers)
      # exclude tests that are not present
      file_to_times_hash.slice!(*all_files)
      min_test_time = file_to_times_hash.values.flatten.min
      setup_time = (min_test_time)/2
      # Any new tests get added in here.
      all_files.each  { |file| file_to_times_hash[file] ||= [min_test_time] }

      files_by_worker = []
      runtimes_by_worker = []

      file_to_times_hash.to_a.sort_by { |a| a.last.max }.reverse_each do |file, times|
        file_runtime = times.max
        if runtimes_by_worker.length < workers
          files_by_worker << [file]
          runtimes_by_worker << file_runtime
        else
          _fastest_worker_time, fastest_worker_index = runtimes_by_worker.each_with_index.min
          files_by_worker[fastest_worker_index] << file
          runtimes_by_worker[fastest_worker_index] += file_runtime - setup_time
        end
      end
      files_by_worker
    end

    def load_manifest(file_name)
      YAML.load_file(file_name) if file_name
    end

    module Strategies
      class << self
        def alphabetically(files, workers)
          files.in_groups(workers)
        end

        def isolated(files, workers)
          files.in_groups_of(1)
        end

        def round_robin(files, workers)
          files.in_groups_of(workers).transpose
        end

        def shuffle(files, workers)
          files.shuffle.in_groups(workers)
        end

        def size(files, workers)
          files.sort_by { |path| File.size(path) }.reverse.in_groups_of(workers).transpose
        end

        def size_greedy_partitioning(files, workers)
          files = files.sort_by { |path| 0 - File.size(path) }
          numbers = (0...workers).to_a
          results = numbers.map { [] }
          sizes = numbers.map { 0 }
          files.each do |file|
            dest = numbers.sort_by { |n| sizes[n] }.first
            sizes[dest] += File.size(file)
            results[dest] << file
          end
          return results
        end

        def size_average_partitioning(files, workers)
          threshold = files.sum { |file| File.size(file) } / workers
          results = []
          this_bucket = []
          this_bucket_size = 0

          files.each do |file|
            if this_bucket_size > threshold && results.size < workers
              results << this_bucket
              this_bucket = []
              this_bucket_size = this_bucket_size - threshold
            end

            this_bucket << file
            this_bucket_size += File.size(file)
          end

          results << this_bucket
          return results
        end
      end
    end
  end
end
