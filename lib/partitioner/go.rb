# frozen_string_literal: true

require 'cocaine'
require 'fileutils'
require 'json'
require 'set'
require 'partitioner/dependency_analysis'

module Partitioner
  # This partitioner shards Go repos
  #
  # See https://docs.google.com/document/d/14z_CWBU3RcK-I6d8PN4ztlIX6C1SSnYg0rokQhjqcKI/edit#
  # for a mini design doc.
  class Go < DependencyAnalysis

    def initialize(build, kochiku_yml)
      super(build, kochiku_yml, {})

      # Go package prefix (e.g., "square/up").
      @package_prefix = ''
      if kochiku_yml
        @package_prefix = kochiku_yml['package_prefix']
      end
    end

    # Run 'test' and 'custom_go_test' for each grouped modules.
    def target_types
      ['test', 'custom_go_test']
    end

    # Run 'build' and 'static_analaysis' only for the top-level package to
    # follow the current script/ci implementation in the Go repo.
    def module_group_target_types
      ['build', 'static_analysis']
    end

    def all_modules
      return @all_modules if @all_modules

      @all_modules = module_dependency_map.keys.select do |m|
        m.start_with?(@package_prefix) && !m.start_with?(@package_prefix + '/vendor')
      end
    end

    # Groups modules by its top-level directory name.
    def module_group_map(modules)
      n = @package_prefix.split("/").length

      # TODO(kaneda): Support 'expand_directories'?
      module_group_map = modules.group_by do |m|
        m.split("/")[n]
      end

      module_group_map.map {|k, ms| ['./' + k, filter_test_packages(ms)] }
    end

    def filter_test_packages(modules)
      n = @package_prefix.length

      ms = Set.new
      modules.each do |m|
        if m.end_with? "_test"
          # Remove trailing "_test".
          ms.add(m[n...-6])
        else
          ms.add(m[n..-1])
        end
      end

      # Convert a set to a list..
      msList = []
      ms.each do |m|
        msList << m
      end
      msList
    end

    def module_dependency_map
      return @module_dependency_map if @module_dependency_map

      @module_dependency_map = {}
      package_info_map.each do |import_path, package_info|
        # Add itself?
        @module_dependency_map[import_path] ||= Set.new
        @module_dependency_map[import_path].add(import_path)

        imports = []
        imports.concat(package_info["Imports"]) unless package_info["Imports"].nil?
        imports.concat(package_info["TestImports"]) unless package_info["TestImports"].nil?
        imports.each do |import|
          @module_dependency_map[import] ||= Set.new
          @module_dependency_map[import].add(import_path)
        end

        xtest_imports = package_info["XTestImports"]
        next if xtest_imports.nil?

        # Add itself?
        test_import_path = import_path + '_test'
        @module_dependency_map[test_import_path] ||= Set.new
        @module_dependency_map[test_import_path].add(test_import_path)

        xtest_imports.each do |import|
          @module_dependency_map[import] ||= Set.new
          @module_dependency_map[import].add(test_import_path)
        end

      end

      @module_dependency_map
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
        unless deps.nil?
          deps.each do |dep|
            tmp_depends_on_map[dep] ||= Set.new
            tmp_depends_on_map[dep].add(import_path)
          end
        end

        test_imports = package_info["TestImports"]
        unless test_imports.nil?
          test_imports.each do |import|
            test_dep_map[import] ||= Set.new
            test_dep_map[import].add(import_path)
          end
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
        # Relocate all the code in src/square/up/
        # Apparently, go list generates bad package names if we don't do this.
        src_dir = FileUtils.mkdir_p("#{dir}/src/square/up")[0]
        Cocaine::CommandLine.new("mv $(git ls-tree --name-only HEAD) #{src_dir}").run

        # Run "go list". Note that the output is NOT a valid single
        # JSON value, but multiple JSON values. See https://github.com/golang/go/issues/12643.
        outputs = Cocaine::CommandLine.new("GOPATH=#{dir} go list -json ./...").run
        l = outputs[1..-3].split("}\n{")
        l.each do |line|
          package_info = JSON.parse("{" + line + "}")
          import_path = package_info["ImportPath"]
          @package_info_map[import_path] = package_info
        end
      end

      @package_info_map
    end

    def file_to_module(file_path)
      # If the file is not a Go file, we are not able to identify
      # tests affected by the file. Just run all tests.
      #
      # TODO(kaneda): Do more smart job here. See
      # https://docs.google.com/document/d/14z_CWBU3RcK-I6d8PN4ztlIX6C1SSnYg0rokQhjqcKI/edit# .
      return nil unless file_path.end_with? '.go'

      dir_path = File.dirname(file_path)
      return nil if dir_path == "."

      @package_prefix + '/' + dir_path
    end

    def deployable_modules_map
      @settings['deployable_branches']
    end
  end
end
