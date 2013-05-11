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

    files_changed_method = build.project.main_build? ? :files_changed_since_last_green : :files_changed_in_branch
    GitBlame.send(files_changed_method, build).each do |changed_file|
      module_to_build = file_to_module(changed_file)
      return partitions if module_to_build.nil?

      modules_to_build.merge(depends_on_map[module_to_build] || Set.new)
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

    transitive_dependency_map = {}

    module_dependency_map.keys.each do |mvn_module|
      transitive_dependency_map[mvn_module] = transitive_dependencies(mvn_module, module_dependency_map)
    end

    @module_dependency_map = transitive_dependency_map
  end

  def transitive_dependencies(mvn_module, dependency_map)
    result_set = Set.new
    to_process = [mvn_module]

    while dep_module = to_process.shift
      deps = dependency_map[dep_module].to_a
      to_process += (deps - result_set.to_a)
      result_set << dep_module
    end

    result_set
  end

  def file_to_module(file_path)
    return nil if file_path.start_with?("parents/")
    dir_path = file_path
    while (dir_path = File.dirname(dir_path)) != "."
      if File.exists?("#{dir_path}/pom.xml")
        return dir_path
      end
    end
    nil
  end

  def deployable_modules_map
    deployable_modules_map = {}

    top_level_pom = Nokogiri::XML(File.read(POM_XML))

    top_level_pom.css('project>modules>module').each do |mvn_module|
      module_pom = Nokogiri::XML(File.read("#{mvn_module.text}/pom.xml"))
      deployable_branch = module_pom.css('project>properties>deployableBranch').first

      if deployable_branch
        deployable_modules_map[mvn_module.text] = "deployable-#{deployable_branch.text}"
      end
    end

    deployable_modules_map
  end

  def self.deployable_modules_map; new.deployable_modules_map; end
end
