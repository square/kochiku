repo_infos = [{:name => 'web'},
              {:name => 'java'},
              {:name => 'other', :last_build_state => :errored, :build_attempt_state => :errored},
              {:name => 'regulator'}]

def create_builds_for(project, repo_info)
  build_state = repo_info[:last_build_state] || :succeeded
  build = Build.create!({:project => project, :ref => SecureRandom.hex, :state => build_state, :queue => "ci"})

  [:spec, :cucumber].each do |kind|
    bp = BuildPart.create!(:build_instance => build, :kind => kind, :paths => ['a'])
    build_attempt_state = repo_info[:build_attempt_state] || :passed
    BuildAttempt.create!(:build_part => bp, :builder => :macbuild01, :state => build_attempt_state, :finished_at => rand(500).seconds.from_now)
  end

end

repo_infos.each do |repo_info|
  repo_name = repo_info[:name]
  repository = Repository.create!({:url => "git@git.squareup.com:square/#{repo_name}.git", :test_command => "script/ci", :run_ci => true})
  project = Project.create!({:name => repo_name, :branch => 'master', :repository => repository})
  create_builds_for(project, repo_info)
end

create_builds_for(Project.find_by_name("regulator"), {:last_build_state => :running, :build_attempt_state => :running})

repository = Repository.create!({:url => "git@git.squareup.com:square/fooo.git", :test_command => "script/ci", :run_ci => true})
project = Project.create!({:name => "fooo", :branch => 'master', :repository => repository})

