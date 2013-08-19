require 'maven_partitioner'

class Partitioner
  KOCHIKU_YML = 'config/ci/kochiku.yml'

  def partitions(build)
    if File.exist?(KOCHIKU_YML)
      # Handle old kochiku.yml
      kochiku_yml = YAML.load_file(KOCHIKU_YML)
      if kochiku_yml.is_a?(Array)
        kochiku_yml.map { |subset| partitions_for(subset) }.flatten
      else
        build_partitions_from(kochiku_yml)
      end
    elsif File.exist?(MavenPartitioner::POM_XML)
      partitioner = MavenPartitioner.new(build)
      build.update_attributes!(:deployable_map => partitioner.deployable_modules_map,
                               :maven_modules => partitioner.maven_modules)
      partitioner.incremental_partitions
    else
      [{'type' => 'spec', 'files' => ['no-manifest']}]
    end
  end

  private

  def build_partitions_from(kochiku_yml)
    kochiku_yml['ruby'].flat_map do |ruby|
      kochiku_yml['targets'].flat_map do |subset|
        partitions_for(
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

  def partitions_for(subset)
    glob = subset.fetch('glob', '/dev/null')
    type = subset.fetch('type', 'test')
    workers = subset.fetch('workers', 1)
    manifest = subset['manifest']

    strategy = subset.fetch('balance', 'alphabetically')
    strategy = 'alphabetically' unless Strategies.respond_to?(strategy)

    files = Array(load_manifest(manifest)) | Dir[*glob]

    file_to_times_hash = load_manifest(subset['time_manifest'])

    balanced_partitions = if file_to_times_hash.is_a?(Hash)
      time_greedy_partitions_for(file_to_times_hash)
    else
      []
    end

    files -= balanced_partitions.flatten

    (Strategies.send(strategy, files, workers) + balanced_partitions).map do |files|
      part = {'type' => type, 'files' => files.compact}
      if subset['options']
        part['options'] = subset['options']
      end
      part
    end.select { |p| p['files'].present? }
  end

  def time_greedy_partitions_for(file_to_times_hash)
    setup_time, max_time = file_to_times_hash.values.flatten.minmax

    files_by_worker = []
    runtimes_by_worker = []

    file_to_times_hash.each do |file, times|
      file_runtime = times.max
      fastest_worker_time, fastest_worker_index = runtimes_by_worker.each_with_index.min
      if fastest_worker_time && fastest_worker_time + file_runtime <= max_time
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
