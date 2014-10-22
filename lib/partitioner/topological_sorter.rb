require 'tsort'

module Partitioner
  class TopologicalSorter
    include TSort

    def initialize(dependency_map)
      @dependency_map = dependency_map
    end

    def tsort_each_node(&block)
      @dependency_map.each_key(&block)
    end

    def tsort_each_child(project, &block)
      @dependency_map.fetch(project).each(&block)
    end
  end
end
