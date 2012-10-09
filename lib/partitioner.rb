class Partitioner
  BUILD_YML   = 'config/ci/build.yml'
  KOCHIKU_YML = 'config/ci/kochiku.yml'

  def partitions
    if File.exist?(KOCHIKU_YML)
      YAML.load_file(KOCHIKU_YML).map { |subset| partitions_for(subset) }.flatten
    elsif File.exist?(BUILD_YML)
      YAML.load_file(BUILD_YML).values.select { |part| part['type'].present? }
    else
      partitions_for({"type" => "spec", "glob" => "spec/**/*_spec.rb", "workers" => 1})
    end
  end

  private

  def partitions_for(subset)
    glob     = subset.fetch('glob')
    type     = subset.fetch('type')
    workers  = subset.fetch('workers')
    manifest = subset['manifest']

    strategy = subset.fetch('balance', 'alphabetically')
    strategy = 'alphabetically' unless Strategies.respond_to?(strategy)

    files = Array(load_manifest(manifest)) | Dir[glob]
    parts = Strategies.send(strategy, files, workers).map do |files|
      { 'type' => type, 'files' => files.compact }
    end

    parts.select { |p| p['files'].present? }
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
        results = numbers.map{ [] }
        sizes   = numbers.map{  0 }
        files.each do |file|
          dest = numbers.sort_by{|n| sizes[n]}.first
          sizes[dest] += File.size(file)
          results[dest] << file
        end
        return results
      end

      def size_average_partitioning(files, workers)
        threshold = files.sum{|file| File.size(file)} / workers
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
