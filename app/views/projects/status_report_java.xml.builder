xml.Projects do
  BuildPart.most_recent_results_for(@project.builds.last.maven_modules).each do |build_part|
    xml.Project({
        :name => build_part.paths.first,
        :activity => build_part.try(:is_running?) ? "Building" : "CheckingModification",
        :lastBuildLabel => build_part.object_id,
        :webUrl => "http://macbuild-master.sfo.squareup.com/projects/#{@project.name}/",
        :lastBuildStatus => build_part.try(:successful?) ? "Success" : "Failure",
        :lastBuildTime => build_part.try(:finished_at).try(:strftime, "%Y-%m-%dT%H:%M:%SZ")
    })
  end
end
