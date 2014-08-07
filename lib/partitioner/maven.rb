require 'nokogiri'
require 'set'

module Partitioner

  # This partitioner uses knowledge of Maven to shard large java repos
  class Maven < Base
    POM_XML = 'pom.xml'

    def initialize(build, kochiku_yml)
      @build = build
      @options = {}
      if kochiku_yml
        @settings = kochiku_yml['maven_settings'] if kochiku_yml['maven_settings']
        @options['log_file_globs'] = Array(kochiku_yml['log_file_globs']) if kochiku_yml['log_file_globs']
      end
      @settings ||= {}
    end

    def partitions
      modules_to_build = Set.new

      GitRepo.inside_copy(@build.repository, @build.ref) do
        @settings.fetch('always_build', []).each do |maven_module|
          modules_to_build.add(maven_module)
        end

        files_changed_method = @build.project.main? ? :files_changed_since_last_build : :files_changed_in_branch
        GitBlame.send(files_changed_method, @build).each do |file_and_emails|
          module_affected_by_file = file_to_module(file_and_emails[:file])

          if module_affected_by_file.nil?
            if file_and_emails[:file] != "pom.xml"
              return all_partitions
            end
          else
            modules_to_build.merge(depends_on_map[module_affected_by_file] || Set.new)
          end
        end

        if @build.project.main? && @build.previous_build
          modules_to_build.merge(@build.previous_build.build_parts.select(&:unsuccessful?).map(&:paths).flatten.uniq)
        end
      end

      group_modules(modules_to_build).map do |group|
        group.merge('options' => @options)
      end
    end

    def emails_for_commits_causing_failures
      return {} unless @build.project.main?

      failed_modules = @build.build_parts.failed_or_errored.inject(Set.new) do |failed_set, build_part|
        build_part.paths.each { |path| failed_set.add(path) }
        failed_set
      end

      email_and_files = Hash.new { |hash, key| hash[key] = [] }

      GitRepo.inside_copy(@build.repository, @build.ref) do
        GitBlame.files_changed_since_last_green(@build, :fetch_emails => true).each do |file_and_emails|
          file = file_and_emails[:file]
          emails = file_and_emails[:emails]
          module_affected_by_file = file_to_module(file_and_emails[:file])

          if module_affected_by_file.nil?
            if file != "pom.xml"
              emails.each { |email| email_and_files[email] << file }
            end
          elsif (set = depends_on_map[module_affected_by_file]) && !set.intersection(failed_modules).empty?
            emails.each { |email| email_and_files[email] << file }
          end
        end
      end

      email_and_files.each_key { |email| email_and_files[email].sort!.uniq! }

      email_and_files
    end

    # Everything below this line should be private

    def maven_modules
      return @maven_modules if @maven_modules
      top_level_pom = Nokogiri::XML(File.read(POM_XML))
      @maven_modules = top_level_pom.css('project>modules>module').map { |mvn_module| mvn_module.text }
    end

    def all_partitions
      group_modules(maven_modules)
    end

    def pom_for(mvn_module)
      Nokogiri::XML(File.read("#{mvn_module}/pom.xml"))
    end

    def group_modules(mvn_modules)
      expanding_dirs = @settings.fetch('expand_directories', [])
      mvn_modules.group_by do |m|
        split_dirs = m.split("/")
        if expanding_dirs.include? split_dirs.first
          "#{split_dirs[0]}/#{split_dirs[1]}"
        else
          split_dirs.first
        end
      end.values.map { |modules| partition_info(modules) }
    end

    def partition_info(mvn_modules)
      queue = @build.project.main? ? 'ci' : 'developer'
      queue_override = @settings.fetch('queue_overrides', []).detect do |override|
        override['queue'] if override['paths'].detect { |path| mvn_modules.include? path }
      end
      queue = "#{queue}-#{queue_override['queue']}" if queue_override.present?
      {
        'type' => 'maven',
        'files' => mvn_modules.sort!,
        'queue' => queue,
        'retry_count' => 2
      }
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

      maven_modules.each do |mvn_module|
        module_pom = pom_for(mvn_module)
        group_id = module_pom.css('project>groupId').first
        artifact_id = module_pom.css('project>artifactId').first
        next unless group_id && artifact_id
        group_id = group_id.text
        artifact_id = artifact_id.text

        group_artifact_map["#{group_id}:#{artifact_id}"] = "#{mvn_module}"
      end

      module_dependency_map = {}

      maven_modules.each do |mvn_module|
        module_pom = pom_for(mvn_module)
        module_dependency_map[mvn_module] ||= Set.new

        module_pom.css('project>dependencies>dependency').each do |dep|
          group_id = dep.css('groupId').first.text
          artifact_id = dep.css('artifactId').first.text

          if mod = group_artifact_map["#{group_id}:#{artifact_id}"]
            module_dependency_map[mvn_module].add(mod)
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
      return nil if @settings.fetch('ignore_directories', []).detect { |dir| file_path.start_with?(dir) }
      dir_path = file_path
      while (dir_path = File.dirname(dir_path)) != "."
        if File.exists?("#{dir_path}/pom.xml")
          return dir_path
        end
      end
      nil
    end
  end
end
