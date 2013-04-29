require 'maven_partitioner'

class Partitioner
  BUILD_YML = 'config/ci/build.yml'
  KOCHIKU_YML = 'config/ci/kochiku.yml'

  def partitions(build)
    if File.exist?(KOCHIKU_YML)
      # Handle old kochiku.yml
      kochiku_yml = YAML.load_file(KOCHIKU_YML)
      if kochiku_yml.is_a?(Array)
        kochiku_yml.map { |subset| partitions_for(subset) }.flatten
      else
        build_partions_from(kochiku_yml)
      end
    elsif File.exist?(BUILD_YML)
      YAML.load_file(BUILD_YML).values.select { |part| part['type'].present? }
    elsif File.exist?(MavenPartitioner::POM_XML)
      MavenPartitioner.new.incremental_partitions(build)
    else
      [{"type" => "spec", "files" => ['no-manifest']}]
    end
  end

  private

  def build_partions_from(kochiku_yml)
    $stderr.puts "DEPRECATED: Your kochiku.yml file contains 'rvm' when it should be 'ruby'. Please update your config." if kochiku_yml.include?("rvm")
    (kochiku_yml["ruby"] || kochiku_yml["rvm"]).map do |rvm|
      options = {"language" => kochiku_yml["language"], "ruby" => rvm}
      kochiku_yml["targets"].map { |subset| partitions_for(subset.merge("options" => options)) }.flatten
    end.flatten
  end

  def partitions_for(subset)
    glob = subset.fetch('glob', '/dev/null')
    type = subset.fetch('type', 'test')
    workers = subset.fetch('workers', 1)
    manifest = subset['manifest']

    strategy = subset.fetch('balance', 'alphabetically')
    strategy = 'alphabetically' unless Strategies.respond_to?(strategy)

    files = Array(load_manifest(manifest)) | Dir[glob]
    parts = Strategies.send(strategy, files, workers).map do |files|
      part = {'type' => type, 'files' => files.compact}
      if subset['options']
        part['options'] = subset['options']
      end
      part
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
