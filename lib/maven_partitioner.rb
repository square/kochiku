require 'nokogiri'
require 'set'

class MavenPartitioner
  POM_XML = 'pom.xml'

  def partitions
    Nokogiri::XML(File.read(POM_XML)).css('project>modules>module').map do |partition|
      {
          'type' => 'maven',
          'files' => [partition.text]
      }
    end
  end

  def incremental_partitions(build)
    modules_to_build = Set.new

    GitBlame.files_changed_since_last_green(build).each do |changed_file|
      modules_to_build.merge(depends_on_map[file_to_module(changed_file)])
    end

    modules_to_build.map do |module_name|
      {
          'type' => 'maven',
          'files' => [module_name]
      }
    end
  end

  def depends_on_map
    return @depends_on_map if @depends_on_map

    module_depends_on_map = {}
    module_dependency_map.each do |mvn_module, dep_set|
      module_depends_on_map[mvn_module] ||= Set.new
      dep_set.each do |dep|
        module_depends_on_map[dep] ||= Set.new
        module_depends_on_map[dep].add(mvn_module)
      end
    end

    @depends_on_map = module_depends_on_map
  end

  def module_dependency_map
    return @module_dependency_map if @module_dependency_map

    group_artifact_map = {}

    top_level_pom = Nokogiri::XML(File.read(POM_XML))

    top_level_pom.css('project>modules>module').each do |mvn_module|
      module_pom = Nokogiri::XML(File.read("#{mvn_module.text}/pom.xml"))

      group_id = module_pom.css('project>groupId').first.text
      artifact_id = module_pom.css('project>artifactId').first.text

      group_artifact_map["#{group_id}:#{artifact_id}"] = "#{mvn_module.text}"
    end

    module_dependency_map = {}

    top_level_pom.css('project>modules>module').each do |mvn_module|
      module_pom = Nokogiri::XML(File.read("#{mvn_module.text}/pom.xml"))
      module_dependency_map["#{mvn_module.text}"] ||= Set.new

      module_pom.css('project>dependencies>dependency').each do |dep|
        group_id = dep.css('groupId').first.text
        artifact_id = dep.css('artifactId').first.text

        if mod = group_artifact_map["#{group_id}:#{artifact_id}"]
          module_dependency_map["#{mvn_module.text}"].add(mod)
        end
      end
    end

    module_dependency_map.each do |mvn_module, dep_set|
      trans_closure_set = dep_set.dup
      size = 0

      while size != trans_closure_set.length do
        working_set = trans_closure_set.dup
        working_set.each do |dep|
          trans_closure_set.merge(module_dependency_map[dep])
        end
        size = working_set.length
      end

      module_dependency_map[mvn_module] = trans_closure_set
    end

    @module_dependency_map = module_dependency_map
  end

  def file_to_module(file_path)
    file_path.split("/src").first
  end
end
