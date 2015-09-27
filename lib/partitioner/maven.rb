require 'nokogiri'
require 'set'
require 'partitioner/base'
require 'partitioner/topological_sorter'

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
        @options['retry_count'] = kochiku_yml['retry_count'] if kochiku_yml['retry_count']
      end
      @settings ||= {}
    end

    def partitions
      modules_to_build = Set.new

      GitRepo.inside_copy(@build.repository, @build.ref) do
        @settings.fetch('always_build', []).each do |maven_module|
          modules_to_build.add(maven_module)
        end

        files_changed_method = @build.branch_record.convergence? ? :files_changed_since_last_build : :files_changed_in_branch
        GitBlame.public_send(files_changed_method, @build, sync: false).each do |file_and_emails|
          next if @settings.fetch('ignore_paths', []).detect { |dir| file_and_emails[:file].start_with?(dir) }

          module_affected_by_file = file_to_module(file_and_emails[:file])

          if module_affected_by_file.nil? || @settings.fetch('build_everything', []).detect { |dir| file_and_emails[:file].start_with?(dir) }
            return add_options(all_partitions)
          else
            modules_to_build.merge(depends_on_map[module_affected_by_file] || Set.new)
          end
        end

        if @build.branch_record.convergence? && @build.previous_build
          modules_to_build.merge(@build.previous_build.build_parts.select(&:unsuccessful?).map(&:paths).flatten.uniq)
        end

        add_options(group_modules(sort_modules(modules_to_build)))
      end
    end

    def emails_for_commits_causing_failures
      return {} unless @build.branch_record.convergence?

      failed_modules = @build.build_parts.failed_or_errored.inject(Set.new) do |failed_set, build_part|
        build_part.paths.each { |path| failed_set.add(path) }
        failed_set
      end

      email_and_files = Hash.new { |hash, key| hash[key] = [] }

      GitRepo.inside_copy(@build.repository, @build.ref) do
        GitBlame.files_changed_since_last_green(@build, fetch_emails: true).each do |file_and_emails|
          file = file_and_emails[:file]
          emails = file_and_emails[:emails]

          module_affected_by_file = file_to_module(file_and_emails[:file])

          if module_affected_by_file.nil? || @settings.fetch('build_everything', []).detect { |dir| file_and_emails[:file].start_with?(dir) }
            emails.each { |email| email_and_files[email] << file }
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
      group_modules(sort_modules(maven_modules))
    end

    def pom_for(mvn_module)
      Nokogiri::XML(File.read("#{mvn_module}/pom.xml"))
    end

    def add_options(group_modules)
      # create multiple entries for builds specifying multiple workers, assigning
      # distinct test chunks to each
      group_modules.flat_map do |group|
        multiple_workers_list = @settings.fetch('multiple_workers', Hash.new)

        multiple_workers_module = multiple_workers_list.keys.detect do |path|
          group['files'].include? path
        end

        need_multiple_workers = multiple_workers_module.present?

        if need_multiple_workers
          total_workers = multiple_workers_list[multiple_workers_module]

          (1..total_workers).map { |worker_chunk|
            new_group = group.clone
            new_options = @options.clone
            new_options['total_workers'] = total_workers
            new_options['worker_chunk'] = worker_chunk

            new_group['options'] = new_options
            new_group
          }
        else
          group['options'] = @options
          group
        end
      end
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

    def sort_modules(mvn_modules)
      sorted_modules = Partitioner::TopologicalSorter.new(module_dependency_map).tsort
      sorted_modules.delete_if { |mvn_module| !mvn_modules.include?(mvn_module) }
    end

    def partition_info(mvn_modules)
      queue = @build.branch_record.convergence? ? 'ci' : 'developer'
      queue_override = @settings.fetch('queue_overrides', []).detect do |override|
        override['queue'] if override['paths'].detect { |path| mvn_modules.include? path }
      end
      queue = "#{queue}-#{queue_override['queue']}" if queue_override.present?
      {
        'type' => 'maven',
        'files' => mvn_modules.sort!,
        'queue' => queue,
        'retry_count' => @options.fetch('retry_count', 2)
      }
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

      maven_modules.each do |mvn_module|
        module_pom = pom_for(mvn_module)
        group_id = module_pom.css('project>groupId').first
        artifact_id = module_pom.css('project>artifactId').first
        next unless group_id && artifact_id
        group_id = group_id.text
        artifact_id = artifact_id.text

        group_artifact_map["#{group_id}:#{artifact_id}"] = "#{mvn_module}"
      end

      @module_dependency_map = {}

      maven_modules.each do |mvn_module|
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
        if File.exist?("#{dir_path}/pom.xml")
          return dir_path
        end
      end
      nil
    end
  end
end
