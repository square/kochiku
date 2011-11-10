class Partitioner
  BUILD_YML   = 'config/ci/build.yml'
  KOCHIKU_YML = 'config/ci/kochiku.yml'

  def partitions
    if File.exist?(KOCHIKU_YML)
      YAML.load_file(KOCHIKU_YML).map { |subset| partitions_for(subset) }.flatten
    else
      YAML.load_file(BUILD_YML).values.select { |part| part['type'].present? }
    end
  end

  private

  def partitions_for(subset)
    glob     = subset.fetch('glob')
    type     = subset.fetch('type')
    workers  = subset.fetch('workers')

    strategy = subset.fetch('balance', 'alphabetically')
    strategy = 'alphabetically' unless Strategies.respond_to?(strategy)

    files = Dir[glob]
    parts = Strategies.send(strategy, files, workers).map do |files|
      { 'type' => type, 'files' => files.compact }
    end

    parts.select { |p| p['files'].present? }
  end

  module Strategies
    class << self
      def alphabetically(files, workers)
        files.in_groups(workers)
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
    end
  end

end
