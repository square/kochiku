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
    glob    = subset.fetch('glob')
    type    = subset.fetch('type')
    workers = subset.fetch('workers')

    parts = Dir[glob].in_groups(workers).map do |files|
      { 'type' => type, 'files' => files.compact }
    end

    parts.select { |p| p['files'].present? }
  end
end
