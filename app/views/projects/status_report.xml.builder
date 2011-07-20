xml.Projects do
  @projects.each do |project|
    # currently cimonitor only utilizes the activity attribute
    xml.Project({:name => project.name, :activity => build_activity(project.builds.last)})
  end
end
