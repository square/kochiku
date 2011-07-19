xml.Projects do
  # currently cimonitor only utilizes the activity attribute
  xml.Project({:name => "web-master", :activity => build_activity(@build)})
end
