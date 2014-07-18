namespace :kochiku do
  desc "Generates time_manifests for a collection of builds; invoke with `rake kochiku:generate_time_manifests['1 2 3 4']`"
  task :generate_time_manifests, [:ids] => [:environment] do |_, args|
    build_ids = args.ids.split

    build_ids.flat_map do |build_id|
      Build.includes(build_parts: :build_attempts).find(build_id).build_parts
    end.group_by(&:kind).map do |kind, parts|
      if parts.map(&:paths).uniq.length > 1
        File.open("#{kind}_time_manifest.yml", 'w') do |io|
          YAML.dump(
            Hash[
              parts.group_by(&:paths).map do |paths, paths_parts|
                [paths.join, paths_parts.map(&:elapsed_time)]
              end
            ],
            io
          )
        end
      end
    end
  end
end
