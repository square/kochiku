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

def write_the_sample_stdout_log_file
  FileUtils.mkdir_p(artifact_directory)
  name = artifact_directory.join('stdout.log')
  File.open(name, 'w') do |file|
    75.times { |i| file.puts "Line #{i}" }
  end
  name
end

def sample_stdout_log_file
  @sample_file ||= artifact_directory.join('stdout.log')
end

def create_build_artifact(attempt)
  BuildArtifact.create!(
    log_file: sample_stdout_log_file.open,
    build_attempt: attempt
  )
end

def create_build_part(build, kind, paths, build_attempt_state)
  bp = BuildPart.create!(:build_instance => build,
                         :kind => kind,
                         :paths => paths,
                         :queue => 'ci')
  build_attempt_state ||= (BuildAttempt::STATES + [:passed] * 5).sample
  finished = if BuildAttempt::IN_PROGRESS_BUILD_STATES.include?(build_attempt_state)
               nil
             else
               rand(500).seconds.from_now
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

def create_build(branch, test_types, build_attempt_state: :passed)
  build = Build.create!(:branch_record => branch,
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

def populate_builds_for(branch, repo_info)
  thread_list = []

  10.times do
    thread_list << Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        create_build(branch, repo_info[:types], build_attempt_state: repo_info[:build_attempt_state])
      end
    end
  end

  thread_list.each { |t| t.join }
end

write_the_sample_stdout_log_file

repos = {}
repo_infos.each do |repo_info|
  repository = Repository.create!({:url => repo_info[:location], :test_command => "script/ci", :run_ci => true})
  repos[repo_info[:name]] = repository
  master_branch = Branch.create!(:name => 'master', :convergence => true, :repository => repository)
  populate_builds_for(master_branch, repo_info)
  developer_branch = Branch.create!(:name => 'feature-branch', :convergence => false, :repository => repository)
  populate_builds_for(developer_branch, repo_info)
end

# create an extra running build for copycopter-server to show something that is in progress
copycopter_branch = Branch.where(repository: repos['copycopter-server'], name: 'master').first
create_build(copycopter_branch, %w(spec), build_attempt_state: :running)
