require 'partitioner/base'
require 'partitioner/go'
require 'partitioner/maven'
require 'partitioner/default'
require 'partitioner/dependency_map'

module Partitioner
  def self.for_build(build)
    kochiku_yml = build.kochiku_yml
    if kochiku_yml
      start = Time.current
      res = case kochiku_yml['partitioner']
            when 'maven'
              Partitioner::Maven.new(build, kochiku_yml)
            when 'go'
              Partitioner::Go.new(build, kochiku_yml)
            when 'dependency_map'
              Partitioner::DependencyMap.new(build, kochiku_yml)
            else
              # Default behavior
              Partitioner::Default.new(build, kochiku_yml)
            end
      finish = Time.current
      diff = finish - start
      Rails.logger.info("Partition finished: [#{kochiku_yml['partitioner'] || 'DEFAULT'}] #{diff} #{build.ref}")
      res
    else
      # This should probably raise
      Partitioner::Base.new(build, kochiku_yml)
    end
  end
end
