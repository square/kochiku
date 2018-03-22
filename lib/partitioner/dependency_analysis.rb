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
      Rails.logger.info("Partition started: [#{target_types}] #{@build.ref}")
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
      Rails.logger.info("Partition finished: [#{target_types}] #{Time.current - start} #{@build.ref}")
    end

    def emails_for_commits_causing_failures
      return {} unless @build.branch_record.convergence?

      failed_modules = @build.build_parts.failed_or_errored.each_with_object(Set.new) do |build_part, failed_set|
        build_part.paths.each { |path| failed_set.add(path) }
      end

      return {} if failed_modules.empty?

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

    # Target types used to create partition info per modules.
    def target_types
      []
    end

    # Target types used to create partition info per module group.
    def module_group_target_types
      []
    end

    def all_modules
      []
    end

    # Groups modules by key.
    def module_group_map(_modules)
      {}
    end

    # Returns a transitive module dependency map
    def depends_on_map
      {}
    end

    # Returns a direct module dependency map
    def module_dependency_map
      {}
    end

    def file_to_module(_file_path)
      nil
    end

    def deployable_modules_map
      nil
    end

    # Everything below this line should be private

    # Create a list of partition infos from modules.
    def group_modules(modules)
      partition_infos = []

      module_group_map(modules).each do |group_key, ms|

        target_types.each do |target_type|
          partition_infos << partition_info(ms, target_type)
        end

        module_group_target_types.each do |target_type|
          partition_infos << partition_info([group_key], target_type)
        end
      end

      partition_infos
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
          group['files'].include?(path)
        end

        if multiple_workers_module.present?
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

    def sort_modules(modules)
      sorted_modules = Partitioner::TopologicalSorter.new(module_dependency_map).tsort
      sorted_modules.delete_if { |m| !modules.include?(m) }
    end

    def partition_info(modules, type)
      queue = @build.branch_record.convergence? ? 'ci' : 'developer'
      queue_override = @settings.fetch('queue_overrides', []).detect do |override|
        override['queue'] if override['paths'].detect { |path| modules.include? path }
      end
      queue = "#{queue}-#{queue_override['queue']}" if queue_override.present?
      {
        'type' => type,
        'files' => modules.sort!,
        'queue' => queue,
        'retry_count' => @options.fetch('retry_count', 0)
      }
    end
  end
end
