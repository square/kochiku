web = Project.create!({:name => 'web', :branch => 'master'})

build = Build.create!({:project => web, :ref => "3abd03269b65d9dc6c92345951e4929cd50b7e61", :state => :partitioning, :queue => "ci"})
