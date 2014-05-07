# Eagerly load all of the models to avoid errors related to multiple threads
Dir[Rails.root.join("app/models/*.rb")].each {|f| require f}

repo_infos = [{:name => 'kandan', :location => "git@github.com:kandanapp/kandan.git", :build_attempt_state => :passed, :types => [:spec, :cucumber]},
              {:name => 'copycopter-server', :build_attempt_state => :passed, :location => "git@github.com:copycopter/copycopter-server.git", :types => [:spec]},
              {:name => 'lobsters', :build_attempt_state => :errored, :location => "git@github.com:jcs/lobsters.git", :types => [:junit]}]

@builders = %w/
  builder01.local builder02.local
/

def artifact_directory
  Rails.root.join('tmp')
end

def write_the_sample_file
  name = artifact_directory.join('build_artifact.log')
  File.open(name, 'w') do |file|
    75.times { |i| file.puts "Line #{i}" }
  end
  name
end

def sample_file
  @sample_file ||= artifact_directory.join('build_artifact.log')
end

def create_build_artifact(attempt)
  BuildArtifact.create!(
    log_file: sample_file.open,
    build_attempt: attempt
  )
end

def create_build_part(build, kind, paths, build_attempt_state)
  bp = BuildPart.create!(:build_instance => build,
                         :kind => kind,
                         :paths => paths,
                         :queue => 'ci')
  build_attempt_state ||= (BuildAttempt::STATES + [:passed] * 5).sample
  if BuildAttempt::IN_PROGRESS_BUILD_STATES.include?(build_attempt_state)
    finished = nil
  else
    finished = rand(500).seconds.from_now
  end
  attempt = BuildAttempt.create!(
    :build_part => bp,
    :builder => @builders.sample,
    :state => build_attempt_state,
    :started_at => Time.now,
    :finished_at => finished
  )
  create_build_artifact(attempt)
  bp
end

def create_build(project, test_types, build_attempt_state: :passed)
  build = Build.create!(:project => project,
                        :ref => SecureRandom.hex(20),
                        :state => :runnable)

  Array(test_types).each do |kind|
    paths = %w(
            spec/controllers/admin/users_controller_spec.rb
            spec/jobs/merchant_location_update_job_spec.rb
            spec/models/loyalty/payer_spec.rb
            spec/views/mailers/application_mailer/interval_sales_report.text.plain.erb_spec.rb
    )

    5.times do
      create_build_part(build, kind, paths, build_attempt_state)
    end
  end

  build.update_state_from_parts!
end

def populate_builds_for(project, repo_info)
  thread_list = []

  10.times do
    thread_list << Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        create_build(project, repo_info[:types], build_attempt_state: repo_info[:build_attempt_state])
      end
    end
  end

  thread_list.each { |t| t.join }
end

write_the_sample_file

repo_infos.each do |repo_info|
  repo_name = repo_info[:name]
  repository = Repository.create!({:url => repo_info[:location], :test_command => "script/ci", :run_ci => true})
  master_project = Project.create!({:name => repo_name, :branch => 'master', :repository => repository})
  populate_builds_for(master_project, repo_info)
  developer_project = Project.create!({:name => "johnny-#{repo_name}", :branch => 'topic-branch', :repository => repository})
  populate_builds_for(developer_project, repo_info)
end

# create an extra running build for copycopter-server to show something that is in progress
create_build(Project.find_by_name("copycopter-server"), %w(spec), build_attempt_state: :running)
