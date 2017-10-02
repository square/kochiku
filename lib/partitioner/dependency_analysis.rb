# frozen_string_literal: true
require 'set'
require 'partitioner/base'
require 'partitioner/topological_sorter'

module Partitioner
  # This partitioner analyzes module dependency to shard repos
  class DependencyAnalysis < Base

    def initialize(build, kochiku_yml, settings)
      @build = build
      @options = {}
      @settings = settings
      if kochiku_yml
        @options['log_file_globs'] = Array(kochiku_yml['log_file_globs']) if kochiku_yml['log_file_globs']
        @options['retry_count'] = kochiku_yml['retry_count'] if kochiku_yml['retry_count']
      end
      @settings ||= {}
    end

    def partitions
      Rails.logger.info("Partition started: [#{partitioner_type}] #{@build.ref}")
      start = Time.current
      modules_to_build = Set.new

      GitRepo.inside_copy(@build.repository, @build.ref) do
        @settings.fetch('always_build', []).each do |m|
          modules_to_build.add(m)
        end

        files_changed_method = @build.branch_record.convergence? ? :files_changed_since_last_build : :files_changed_in_branch
        GitBlame.public_send(files_changed_method, @build, sync: false).each do |file_and_emails|
          next if @settings.fetch('ignore_paths', []).detect { |dir| file_and_emails[:file].start_with?(dir) }

          module_affected_by_file = file_to_module(file_and_emails[:file])

          if module_affected_by_file.nil? ||
             @settings.fetch('build_everything', []).detect { |dir| file_and_emails[:file].start_with?(dir) }

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
    ensure
      # TODO: log this information to event stream
      Rails.logger.info("Partition finished: [#{partitioner_type}] #{Time.current - start} #{@build.ref}")
    end

    def emails_for_commits_causing_failures
      return {} unless @build.branch_record.convergence?

      failed_modules = @build.build_parts.failed_or_errored.each_with_object(Set.new) do |build_part, failed_set|
        build_part.paths.each { |path| failed_set.add(path) }
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

    # Everything below this line should be protected

    def type
      nil
    end

    def all_modules
      []
    end

    def module_dependency_map
      {}
    end

    def file_to_module(_file_path)
      nil
    end

    def all_partitions
      group_modules(sort_modules(all_modules))
    end

    def add_options(group_modules)
      # create multiple entries for builds specifying multiple workers, assigning
      # distinct test chunks to each
      group_modules.flat_map do |group|
        multiple_workers_list = @settings.fetch('multiple_workers', {})

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

    def group_modules(modules)
      expanding_dirs = @settings.fetch('expand_directories', [])
      modules.group_by do |m|
        split_dirs = m.split("/")
        if expanding_dirs.include? split_dirs.first
          "#{split_dirs[0]}/#{split_dirs[1]}"
        else
          split_dirs.first
        end
      end.values.map { |m| partition_info(m) }
    end

    def sort_modules(modules)
      sorted_modules = Partitioner::TopologicalSorter.new(module_dependency_map).tsort
      sorted_modules.delete_if { |m| !modules.include?(m) }
    end

    def partition_info(modules)
      queue = @build.branch_record.convergence? ? 'ci' : 'developer'
      queue_override = @settings.fetch('queue_overrides', []).detect do |override|
        override['queue'] if override['paths'].detect { |path| modules.include? path }
      end
      queue = "#{queue}-#{queue_override['queue']}" if queue_override.present?
      {
        'type' => partitioner_type,
        'files' => modules.sort!,
        'queue' => queue,
        'retry_count' => @options.fetch('retry_count', 0)
      }
    end

    def depends_on_map
      return @depends_on_map if @depends_on_map

      module_depends_on_map = {}
      transitive_dependency_map.each do |module_name, dep_set|
        module_depends_on_map[module_name] ||= Set.new
        module_depends_on_map[module_name].add(module_name)
        dep_set.each do |dep|
          module_depends_on_map[dep] ||= Set.new
          module_depends_on_map[dep].add(dep)
          module_depends_on_map[dep].add(module_name)
        end
      end

      @depends_on_map = module_depends_on_map
    end

    def transitive_dependency_map
      @transitive_dependency_map ||= begin
        module_dependency_map.each_with_object({}) do |(module_name, _), dep_map|
          dep_map[module_name] = transitive_dependencies(module_name, module_dependency_map)
        end
      end
    end

    def transitive_dependencies(module_name, dependency_map)
      result_set = Set.new
      to_process = [module_name]

      while (dep_module = to_process.shift)
        deps = dependency_map[dep_module].to_a
        to_process += (deps - result_set.to_a)
        result_set << dep_module
      end

      result_set
    end
  end
end
