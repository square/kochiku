class Partitioner
  def initialize(config)
    @config = config
  end

  def partitions
    @config.map { |subset| partitions_for(subset) }.flatten
  end

  private

  def partitions_for(subset)
    glob    = subset.fetch('glob')
    type    = subset.fetch('type')
    workers = subset.fetch('workers')

    partitions = Dir[glob].in_groups(workers).map do |files|
      { 'type' => type, 'files' => files.compact }
    end

    partitions.reject { |p| p['files'].empty? }
  end
end
