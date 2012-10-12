web_repo = Repository.create!({:url => "git@git.squareup.com:square/web.git", :test_command => "script/ci"})
web = Project.create!({:name => 'web', :branch => 'master', :repository => web_repo})

build = Build.create!({:project => web, :ref => "3abd03269b65d9dc6c92345951e4929cd50b7e61", :state => :succeeded, :queue => "ci"})


[:spec, :cucumber].each do |kind|
  bp = BuildPart.create!(:build_instance => build, :kind => kind, :paths => ['a'])
  BuildAttempt.create!(:build_part => bp, :builder => :macbuild01, :state => :passed)
end
