xml.Projects do
  @projects.each do |project|
    # currently cimonitor only utilizes the activity attribute
    if project.name == "java" # Separate reporting for each java module
      project.builds.last.build_parts.each do |java_module|
        xml.Project({
                      :name => java_module.paths.first,
                      :activity => java_module.try(:is_running?) ? "Building" : "CheckingModification",
                      :lastBuildLabel => java_module.object_id,
                      :webUrl => "http://macbuild-master.sfo.squareup.com/projects/#{project.name}/",
                      :lastBuildStatus => java_module.try(:successful?) ? "Success" : "Failure",
                      :lastBuildTime => java_module.try(:finished_at).try(:strftime, "%Y-%m-%dT%H:%M:%SZ")
                    })
      end
    else
      xml.Project({
                    :name => project.name,
                    :activity => build_activity(project.builds.last),
                    :lastBuildLabel => project.builds.last.object_id,
                    :webUrl => "http://macbuild-master.sfo.squareup.com/projects/#{project.name}/",
                    :lastBuildStatus => (project.last_completed_build.try(:succeeded?) ? "Success" : "Failure"),
                    :lastBuildTime => project.last_completed_build.try(:finished_at).try(:strftime, "%Y-%m-%dT%H:%M:%SZ")
                  })
    end
  end
end
