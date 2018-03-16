# frozen_string_literal: true
require 'set'
require 'partitioner/base'
require 'partitioner/topological_sorter'
require 'partitioner/dependency_analysis'

module Partitioner
  # This partitioner uses knowledge of Maven to shard large java repos
  class Maven < DependencyAnalysis
    POM_XML = 'pom.xml'

    def initialize(build, kochiku_yml)
      settings = {}
      if kochiku_yml
        settings = kochiku_yml['maven_settings'] if kochiku_yml['maven_settings']
      end
      super(build, kochiku_yml, settings)
    end

    def target_types
      ['maven']
    end

    def all_modules
      return @all_modules if @all_modules
      top_level_pom = Nokogiri::XML(File.read(POM_XML))
      @all_modules = top_level_pom.css('project>modules>module').map { |mvn_module| mvn_module.text }
    end

    def pom_for(mvn_module)
      Nokogiri::XML(File.read("#{mvn_module}/pom.xml"))
    end

    def module_group_map(mvn_modules)
      expanding_dirs = @settings.fetch('expand_directories', [])
      mvn_modules.group_by do |m|
        split_dirs = m.split("/")
        if expanding_dirs.include? split_dirs.first
          "#{split_dirs[0]}/#{split_dirs[1]}"
        else
          split_dirs.first
        end
      end
    end

    def depends_on_map
      return @depends_on_map if @depends_on_map

      module_depends_on_map = {}
      transitive_dependency_map.each do |mvn_module, dep_set|
        module_depends_on_map[mvn_module] ||= Set.new
        module_depends_on_map[mvn_module].add(mvn_module)
        dep_set.each do |dep|
          module_depends_on_map[dep] ||= Set.new
          module_depends_on_map[dep].add(dep)
          module_depends_on_map[dep].add(mvn_module)
        end
      end

      @depends_on_map = module_depends_on_map
    end

    def module_dependency_map
      return @module_dependency_map if @module_dependency_map

      group_artifact_map = {}

      all_modules.each do |mvn_module|
        module_pom = pom_for(mvn_module)
        group_id = module_pom.css('project>groupId').first
        artifact_id = module_pom.css('project>artifactId').first
        next unless group_id && artifact_id
        group_id = group_id.text
        artifact_id = artifact_id.text

        group_artifact_map["#{group_id}:#{artifact_id}"] = mvn_module.to_s
      end

      @module_dependency_map = {}

      all_modules.each do |mvn_module|
        module_pom = pom_for(mvn_module)
        @module_dependency_map[mvn_module] ||= Set.new

        module_pom.css('project>dependencies>dependency').each do |dep|
          group_id = dep.css('groupId').first
          artifact_id = dep.css('artifactId').first

          raise "dependency in #{mvn_module}/pom.xml is missing an artifactId or groupId" unless group_id && artifact_id

          if (mod = group_artifact_map["#{group_id.text}:#{artifact_id.text}"])
            module_dependency_map[mvn_module].add(mod)
          end
        end
      end

      @module_dependency_map
    end

    def transitive_dependency_map
      @transitive_dependency_map ||= begin
        module_dependency_map.each_with_object({}) do |(mvn_module, _), dep_map|
          dep_map[mvn_module] = transitive_dependencies(mvn_module, module_dependency_map)
        end
      end
    end

    def transitive_dependencies(mvn_module, dependency_map)
      result_set = Set.new
      to_process = [mvn_module]

      while (dep_module = to_process.shift)
        deps = dependency_map[dep_module].to_a
        to_process += (deps - result_set.to_a)
        result_set << dep_module
      end

      result_set
    end

    def file_to_module(file_path)
      dir_path = file_path
      while (dir_path = File.dirname(dir_path)) != "."
        return dir_path if File.exist?("#{dir_path}/pom.xml")
      end
      nil
    end
  end
end
