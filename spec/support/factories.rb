FactoryGirl.define do
  factory :project do
    sequence(:name) {|n| "Project_#{n}" }
    association :repository
    branch "master"

    factory :big_rails_project do
      name "web"
      branch "master"
    end

    factory :main_project do
      name { repository.repository_name }
    end
  end

  factory :build do
    project
    state :partitioning
    ref { SecureRandom.hex }

    factory :main_project_build do
      association :project, :factory => :main_project
    end
  end

  factory :build_part do
    association :build_instance, :factory => :build, :state => :runnable
    kind :test
    paths ["/foo/1.test", "foo/baz/a.test", "foo/baz/b.test"]
    queue :ci
  end

  factory :build_attempt do
    build_part
    state :runnable
  end

  factory :build_artifact do
    association :build_attempt, :state => :failed
    log_file File.open(FIXTURE_PATH + "build_artifact.log")
  end

  factory :repository do
    url "git@github.com:square/test-repo.git"  # this repo does not exist on purpose
    test_command "script/ci worker"
    on_green_update 'last-green-build'
  end
end
