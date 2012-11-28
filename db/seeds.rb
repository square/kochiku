repo_infos = [{:name => 'web'},
              {:name => 'java'},
              {:name => 'other', :build_attempt_state => :errored},
              {:name => 'regulator', :build_attempt_state => :passed}]

@builders = %w/
  macbuild01.local macbuild02.local macbuild03.local
  work01.ec2.squareup.com work02.ec2.squareup.com work03.ec2.squareup.com
/

def create_builds_for(project, repo_info)
  build = Build.create!(:project => project,
                        :ref => SecureRandom.hex,
                        :state => :runnable,
                        :queue => "ci")

  [:spec, :cucumber].each do |kind|
    10.times do
      bp = BuildPart.create!(:build_instance => build,
                             :kind => kind,
                             :paths => ['a'])
      build_attempt_state = repo_info[:build_attempt_state] || (BuildAttempt::STATES + [:passed] * 5).sample
      BuildAttempt.create!(:build_part => bp, :builder => @builders.sample,
                           :state => build_attempt_state,
                           :started_at => Time.now,
                           :finished_at => BuildAttempt::IN_PROGRESS_BUILD_STATES.include?(build_attempt_state) ? nil : rand(500).seconds.from_now)
    end
  end

  build.update_state_from_parts!
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
