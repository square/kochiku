web = Project.create!({:name => 'web', :branch => 'master'})

build = Build.create!({:project => web, :ref => "3abd03269b65d9dc6c92345951e4929cd50b7e61", :state => :succeeded, :queue => "ci"})


[:spec, :cucumber].each do |kind|
  bp = BuildPart.create!(:build_instance => build, :kind => kind, :paths => ['a'])
  BuildAttempt.create!(:build_part => bp, :builder => :macbuild01, :state => :passed)
end
