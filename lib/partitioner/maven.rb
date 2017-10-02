# frozen_string_literal: true
require 'set'
require 'partitioner/base'
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

    def partitioner_type
      'maven'
    end

    def all_modules
      return @all_modules if @all_modules
      top_level_pom = Nokogiri::XML(File.read(POM_XML))
      @all_modules = top_level_pom.css('project>modules>module').map { |mvn_module| mvn_module.text }
    end

    def pom_for(mvn_module)
      Nokogiri::XML(File.read("#{mvn_module}/pom.xml"))
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

    def file_to_module(file_path)
      dir_path = file_path
      while (dir_path = File.dirname(dir_path)) != "."
        return dir_path if File.exist?("#{dir_path}/pom.xml")
      end
      nil
    end
  end
end
