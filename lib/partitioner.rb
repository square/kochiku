require 'partitioner/base'
require 'partitioner/maven'
require 'partitioner/default'

module Partitioner
  def self.for_build(build)
    kochiku_yml = build.kochiku_yml
    if kochiku_yml
      start = Time.now
      res = case kochiku_yml['partitioner']
            when 'maven'
              Partitioner::Maven.new(build, kochiku_yml)
            else
              # Default behavior
              Partitioner::Default.new(build, kochiku_yml)
            end
      finish = Time.now
      diff = finish - start
      Rails.logger.info("Partition finished: [#{kochiku_yml['partitioner'] || 'DEFAULT'}] #{diff} #{build.ref}")
      res
    else
      # This should probably raise
      Partitioner::Base.new(build, kochiku_yml)
    end
  end
end
