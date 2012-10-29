repo_infos = [{:name => 'web'},
              {:name => 'java'},
              {:name => 'other', :last_build_state => :errored},
              {:name => 'regulator'}]

repo_infos.each do |repo_info|
  repo_name = repo_info[:name]
  repository = Repository.create!({:url => "git@git.squareup.com:square/#{repo_name}.git", :test_command => "script/ci", :run_ci => true})
  project = Project.create!({:name => repo_name, :branch => 'master', :repository => repository})

  build_state = repo_info[:last_build_state] || :succeeded
  build = Build.create!({:project => project, :ref => "3abd03269b65d9dc6c92345951e4929cd50b7e61", :state => build_state, :queue => "ci"})

  [:spec, :cucumber].each do |kind|
    bp = BuildPart.create!(:build_instance => build, :kind => kind, :paths => ['a'])
    build_attempt_state = build.state == :succeeded ? :passed : :errored
    BuildAttempt.create!(:build_part => bp, :builder => :macbuild01, :state => build_attempt_state)
  end

end

repository = Repository.create!({:url => "git@git.squareup.com:square/fooo.git", :test_command => "script/ci", :run_ci => true})
project = Project.create!({:name => "fooo", :branch => 'master', :repository => repository})

