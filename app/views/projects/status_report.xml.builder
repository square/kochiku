xml.Projects do
  @projects.each do |project|
    # currently cimonitor only utilizes the activity attribute
    xml.Project({
      :name => project.name,
      :activity => build_activity(project.builds.last),
      :lastBuildLabel => project.builds.last.object_id,
      :webUrl => "#{Settings.kochiku_host_with_protocol}/projects/#{project.name}/",
      :lastBuildStatus => (project.last_completed_build.try(:succeeded?) ? "Success" : "Failure"),
      :lastBuildTime => project.last_completed_build.try(:finished_at).try(:strftime, "%Y-%m-%dT%H:%M:%SZ")
    })
  end
end
