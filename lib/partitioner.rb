class Partitioner
  KOCHIKU_YML_LOC_1 = 'config/kochiku.yml'
  KOCHIKU_YML_LOC_2 = 'config/ci/kochiku.yml'

  def partitions(build)
    if kochiku_yml_location
      # Handle old kochiku.yml
      if kochiku_yml.is_a?(Array)
        kochiku_yml.map { |subset| partitions_for(build, subset) }.flatten
      else
        build_partitions(build)
      end
    else
      [{'type' => 'spec', 'files' => ['no-manifest'], 'queue' => queue_for_build(build), 'retry_count' => 0}]
    end
  end

  private

  def kochiku_yml
    @kochiku_yml ||= YAML.load_file(kochiku_yml_location)
  end

  # Returns location of the kochiku.yml file within the repository. Returns nil
  # if the file is not present.
  def kochiku_yml_location
    if File.exist?(KOCHIKU_YML_LOC_1)
      KOCHIKU_YML_LOC_1
    elsif File.exist?(KOCHIKU_YML_LOC_2)
      KOCHIKU_YML_LOC_2
    end
  end

  def max_build_time
    if kochiku_yml.is_a?(Array)
      kochiku_yml
    else
      kochiku_yml.fetch('targets')
    end.map do |subset|
      file_to_times_hash = load_manifest(subset['time_manifest'])
      if file_to_times_hash.is_a?(Hash)
        file_to_times_hash.values
      end
    end.flatten.compact.max
  end

  def build_partitions(build)
    kochiku_yml['ruby'].flat_map do |ruby|
      kochiku_yml['targets'].flat_map do |subset|
        partitions_for(
          build,
          subset.merge(
            'options' => {
              'language' => kochiku_yml['language'],
              'ruby' => ruby,
            }
          )
        )
      end
    end
  end

  def partitions_for(build, subset)
    glob = subset.fetch('glob', '/dev/null')
    type = subset.fetch('type', 'test')
    workers = subset.fetch('workers', 1)
    manifest = subset['manifest']
    retry_count = subset['retry_count'] || 0

    append_type_to_queue = subset.fetch('append_type_to_queue', false)
    queue = queue_for_build(build)
    queue += "-#{type}" if append_type_to_queue

    queue_override = subset.fetch('queue_override', nil)
    queue = queue_override if queue_override.present?

    strategy = subset.fetch('balance', 'alphabetically')
    strategy = 'alphabetically' unless Strategies.respond_to?(strategy)

    files = Array(load_manifest(manifest)) | Dir[*glob]

    file_to_times_hash = load_manifest(subset['time_manifest'])

    balanced_partitions = if file_to_times_hash.is_a?(Hash)
      @max_time ||= max_build_time
      time_greedy_partitions_for(file_to_times_hash)
    else
      []
    end

    files -= balanced_partitions.flatten

    (Strategies.send(strategy, files, workers) + balanced_partitions).map do |files|
      part = {'type' => type, 'files' => files.compact, 'queue' => queue, 'retry_count' => retry_count}
      if subset['options']
        part['options'] = subset['options']
      end
      part
    end.select { |p| p['files'].present? }
  end

  def queue_for_build(build)
    build.project.main? ? 'ci' : 'developer'
  end

  def time_greedy_partitions_for(file_to_times_hash)
    setup_time = file_to_times_hash.values.flatten.min

    files_by_worker = []
    runtimes_by_worker = []

    file_to_times_hash.to_a.sort_by { |a| a.last.max }.reverse.each do |file, times|
      file_runtime = times.max
      fastest_worker_time, fastest_worker_index = runtimes_by_worker.each_with_index.min
      if fastest_worker_time && fastest_worker_time + (file_runtime - setup_time) <= @max_time
        files_by_worker[fastest_worker_index] << file
        runtimes_by_worker[fastest_worker_index] += file_runtime - setup_time
      else
        files_by_worker << [file]
        runtimes_by_worker << file_runtime
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
