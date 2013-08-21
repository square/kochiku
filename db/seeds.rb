repo_infos = [{:name => 'kandan', :location => "git@github.com:kandanapp/kandan.git", :build_attempt_state => :passed},
              {:name => 'copycopter-server', :build_attempt_state => :passed, :location => "git@github.com:copycopter/copycopter-server.git"},
              {:name => 'lobsters', :build_attempt_state => :errored, :location => "git@github.com:jcs/lobsters.git"}]

@builders = %w/
  builder01.local builder02.local
/

def create_build_part(build, kind, paths, build_attempt_state)
  bp = BuildPart.create!(:build_instance => build,
                         :kind => kind,
                         :paths => paths)
  build_attempt_state ||= (BuildAttempt::STATES + [:passed] * 5).sample
  BuildAttempt.create!(:build_part => bp, :builder => @builders.sample,
                       :state => build_attempt_state,
                       :started_at => Time.now,
                       :finished_at => BuildAttempt::IN_PROGRESS_BUILD_STATES.include?(build_attempt_state) ? nil : rand(500).seconds.from_now)
end

def create_builds_for(project, repo_info)
  10.times do
    build = Build.create!(:project => project,
                          :ref => SecureRandom.hex,
                          :state => :runnable,
                          :queue => "ci")

    (repo_info[:types] || [:spec, :cucumber]).each do |kind|
      if repo_info[:paths]
        repo_info[:paths].each do |path|
          create_build_part(build, kind, [ path ], repo_info[:build_attempt_state])
        end
      else
        10.times do
          paths = %w(
            spec/controllers/admin/users_controller_spec.rb
            spec/jobs/merchant_location_update_job_spec.rb
            spec/models/loyalty/payer_spec.rb
            spec/views/mailers/application_mailer/interval_sales_report.text.plain.erb_spec.rb
          )
          create_build_part(build, kind, paths, repo_info[:build_attempt_state])
        end
      end
    end

    build.update_state_from_parts!
  end
end

repo_infos.each do |repo_info|
  repo_name = repo_info[:name]
  repository = Repository.create!({:url => repo_info[:location], :test_command => "script/ci", :run_ci => true})
  master_project = Project.create!({:name => repo_name, :branch => 'master', :repository => repository})
  create_builds_for(master_project, repo_info)
  developer_project = Project.create!({:name => "johnny-#{repo_name}", :branch => 'topic-branch', :repository => repository})
  create_builds_for(developer_project, repo_info)
end

# create an extra running build for copycopter-server to show something that is in progress
create_builds_for(Project.find_by_name("copycopter-server"), {:last_build_state => :running, :build_attempt_state => :running})
