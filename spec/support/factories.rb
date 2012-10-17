FactoryGirl.define do
  factory :project do
    sequence(:name) {|n| "Project_#{n}" }
    association :repository

    factory :big_rails_project do
      name "web"
      branch "master"
    end
  end

  factory :build do
    project
    state :partitioning
    queue :ci
    ref { SecureRandom.hex }
  end

  factory :build_part do
    association :build_instance, :factory => :build, :state => :runnable
    kind :test
    paths ["/foo/1.test", "foo/baz/a.test", "foo/baz/b.test"]
  end

  factory :build_attempt do
    build_part
    state :runnable
  end

  factory :build_artifact do
    build_attempt
    log_file File.open(FIXTURE_PATH + "build_artifact.log")
  end

  factory :repository do
    url "git@git.squareup.com:square/kochiku.git"
    test_command "script/ci worker"
  end
end