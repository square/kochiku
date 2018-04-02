# frozen_string_literal: true

require 'cocaine'
require 'fileutils'
require 'json'
require 'set'
require 'partitioner/base'

module Partitioner
  # This partitioner shards Go repos
  # Example usage
  ################################
  # partitioner: go
  # go_partitioner_settings:
  #   ignore_paths:
  #     - kochiku.yml
  #   all_packages:
  #     test:
  #       # All others will run on 1 worker
  #       items : 4
  #       inventory2: 2
  #     custom_go: 4
  #   top_level_packages:
  #     build: 4
  #     static_analysis: 1
  #   package_prefix: "square/up"
  ################################

  class Go < Base

    def initialize(build, kochiku_yml)
      @build = build
      @options = {}
      @settings = {}
      if kochiku_yml
        @settings = kochiku_yml['go_partitioner_settings'] if kochiku_yml['go_partitioner_settings']
        @options['log_file_globs'] = Array(kochiku_yml['log_file_globs']) if kochiku_yml['log_file_globs']
        @options['retry_count'] = kochiku_yml['retry_count'] if kochiku_yml['retry_count']
      end

      # Go package prefix (e.g., "square/up").
      @package_prefix = @settings['package_prefix'] ? File.join(@settings['package_prefix'], '') : ''
    end

    def partitions
      Rails.logger.info("Partition started: [#{all_packages_target_types} #{top_level_packages_target_types}] #{@build.ref}")
      start = Time.current
      packages_to_build = []

      files_changed_method = @build.branch_record.convergence? ? :files_changed_since_last_build : :files_changed_in_branch

      GitBlame.public_send(files_changed_method, @build, sync: false).each do |file_and_emails|
        file_path = file_and_emails[:file]
        next if @settings.fetch('ignore_paths', []).detect { |dir| file_path.start_with?(dir) }

        # build all for top level file changes
        dir_path = File.dirname(file_path)
        return add_partitions(all_packages) if dir_path == "."

        packages_to_build += file_to_packages(file_path)
      end

      packages_to_build += failed_convergence_tests
      add_partitions(packages_to_build.uniq)
    ensure
      Rails.logger.info("Partition finished: [#{all_packages_target_types} #{top_level_packages_target_types}] #{Time.current - start} #{@build.ref}")
    end

    def file_to_packages(file_path)
      dir_path = File.dirname(file_path)
      if file_path.end_with? '.go'
        path_affected_by_file = @package_prefix + dir_path
        return Array(depends_on_map[path_affected_by_file])
      # if its not a go file run all tests in top-level package
      else
        top_level_package = dir_path.split("/").first
        return Array(top_level_package_map[@package_prefix + top_level_package])
      end
    end

    def failed_convergence_tests
      # add in the packages that failed previously if its the convergence branch
      if @build.branch_record.convergence? && @build.previous_build
        previous_failures = @build.previous_build.build_parts.select(&:unsuccessful?).map(&:paths).flatten.uniq
        previous_failures.map! { |path| @package_prefix + path }
      end
      previous_failures || []
    end

    # Run for each packages.
    def all_packages_target_types
      @all_packages_target_types ||= @settings['all_packages'] || {test: 1}
    end

    # Run only for the top-level package
    def top_level_packages_target_types
      @top_level_packages_target_types ||= @settings['top_level_packages'] || {build: 1}
    end

    def all_packages
      @all_packages ||= package_dependency_map.keys.select do |m|
        m.start_with?(@package_prefix) && !m.start_with?(File.join(@package_prefix, 'vendor'))
      end
    end

    def top_level_package_map
      @top_level_package_map ||= filter_test(all_packages).group_by { |package| package.match(%r{^#{@package_prefix}+[^\/]*})[0] }
    end

    # Group folders by their top-level package name.
    def package_folders_map(packages)
      package_folders_map = filter_test(packages).group_by { |package| package.match(%r{^#{@package_prefix}+[^\/]*})[0] }
      package_folders_map.each { |k, v| package_folders_map[k] = v.map { |vv| package_to_folder(vv) } }
    end

    def package_to_folder(package)
      File.join('.', package.gsub(/^#{@package_prefix}/, ""), '')
    end

    def filter_test(packages)
      packages.reject { |pack| pack.match(/_test$/) }
    end

    def package_dependency_map
      return @package_dependency_map if @package_dependency_map

      @package_dependency_map = {}
      package_info_map.each do |import_path, package_info|
        # Add itself?
        @package_dependency_map[import_path] ||= Set.new
        @package_dependency_map[import_path].add(import_path)

        imports = []
        imports.concat(package_info["Imports"]) unless package_info["Imports"].nil?
        imports.concat(package_info["TestImports"]) unless package_info["TestImports"].nil?
        imports.each do |import|
          @package_dependency_map[import] ||= Set.new
          @package_dependency_map[import].add(import_path)
        end

        xtest_imports = package_info["XTestImports"]
        next if xtest_imports.nil?

        # Add itself?
        test_import_path = import_path + '_test'
        @package_dependency_map[test_import_path] ||= Set.new
        @package_dependency_map[test_import_path].add(test_import_path)

        xtest_imports.each do |import|
          @package_dependency_map[import] ||= Set.new
          @package_dependency_map[import].add(test_import_path)
        end

      end

      @package_dependency_map
    end

    def depends_on_map
      return @depends_on_map if @depends_on_map

      # Create a map on transitive non-test dependency
      # and a map on direct test dependency.
      tmp_depends_on_map = {}
      test_dep_map = {}
      package_info_map.each do |import_path, package_info|
        # Add itself?
        tmp_depends_on_map[import_path] ||= Set.new
        tmp_depends_on_map[import_path].add(import_path)

        deps = package_info["Deps"]
        deps&.each do |dep|
          tmp_depends_on_map[dep] ||= Set.new
          tmp_depends_on_map[dep].add(import_path)
        end

        test_imports = package_info["TestImports"]
        test_imports&.each do |import|
          test_dep_map[import] ||= Set.new
          test_dep_map[import].add(import_path)
        end

        xtest_imports = package_info["XTestImports"]
        next if xtest_imports.nil?

        # Add itself?
        test_import_path = import_path + '_test'
        tmp_depends_on_map[test_import_path] ||= Set.new
        tmp_depends_on_map[test_import_path].add(test_import_path)

        xtest_imports.each do |import|
          test_dep_map[import] ||= Set.new
          test_dep_map[import].add(test_import_path)
        end
      end

      @depends_on_map = {}

      tmp_depends_on_map.each do |import_path, deps|
        @depends_on_map[import_path] = Set.new

        deps.each do |dep|
          @depends_on_map[import_path].add(dep)

          test_deps = test_dep_map[dep]
          next if test_deps.nil?
          test_deps.each do |test_dep|
            @depends_on_map[import_path].add(test_dep)
          end
        end
      end

      @depends_on_map
    end

    def package_info_map
      return @package_info_map if @package_info_map

      @package_info_map = {}

      GitRepo.inside_copy(@build.repository, @build.ref) do |dir|
        # Relocate all the code in src/#{@package_prefix}
        # Apparently, go list generates bad package names if we don't do this.
        src_dir = FileUtils.mkdir_p(File.join(dir, "src", @package_prefix))[0]
        Cocaine::CommandLine.new("mv $(git ls-tree --name-only HEAD) #{src_dir}").run

        # Run "go list". Note that the output is NOT a valid single
        # JSON value, but multiple JSON values. See https://github.com/golang/go/issues/12643.
        outputs = Cocaine::CommandLine.new("GOPATH=#{dir} go list -json ./...").run
        l = outputs[1..-3].split("}\n{")
        l.each do |blob|
          package_info = JSON.parse("{" + blob + "}")
          import_path = package_info["ImportPath"]
          @package_info_map[import_path] = package_info
        end
      end

      @package_info_map
    end

    def add_partitions(packages)
      @partition_list = []
      package_map = package_folders_map(packages)

      all_packages_target_types.each do |target_type, workers|
        if workers.is_a?(Hash)
          package_map.each do |package, folders|
            worker_number = workers[package.gsub(/^#{@package_prefix}/, "")]
            add_with_split(folders, target_type, worker_number)
          end
        elsif workers.is_a?(Integer)
          add_with_split(package_map.map { |_, v| v }.flatten.uniq, target_type, workers)
        end
      end

      top_level_packages_target_types.each do |target_type, workers|
        if workers.is_a?(Hash)
          package_map.each do |package, folders|
            worker_number = workers[package.gsub(/^#{@package_prefix}/, "")]
            add_with_split(folders, target_type, worker_number)
          end
        elsif workers.is_a?(Integer)
          add_with_split(package_map.map { |k, _| package_to_folder(k) }.uniq, target_type, workers)
        end
      end

      @partition_list
    end

    def add_with_split(package_list, target_type, workers)
      return if package_list.size.zero?
      if workers
        split_size = (package_list.size / workers.to_f).ceil
        Array(package_list).each_slice(split_size).to_a.each do |chunk|
          @partition_list << partition_info(chunk, target_type)
        end
      else
        @partition_list << partition_info(package_list, target_type)
      end
    end

    def partition_info(packages, type)
      queue = @build.branch_record.convergence? ? 'ci' : 'developer'
      queue_override = @settings.fetch('queue_overrides', []).detect do |override|
        override['queue'] if override['paths']&.detect { |path| packages.include? path }
      end
      queue = "#{queue}-#{queue_override['queue']}" if queue_override.present?
      {
        'type' => type,
        'files' => packages&.sort!,
        'queue' => queue,
        'retry_count' => @options.fetch('retry_count', 0),
        'options' => @options
      }
    end
  end
end
