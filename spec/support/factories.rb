FactoryGirl.define do
  factory :project do
    sequence(:name) {|n| "Project ##{n}" }
  end

  factory :big_rails_project, :class => :project do
    name "web"
    branch "master"
  end

  factory :build do
    project
    state :partitioning
    queue :ci
    ref { ActiveSupport::SecureRandom.hex }
  end

  # NB: a build_attempt is created as a side effect of creating a build_part
  factory :build_part do
    association :build_instance, :factory => :build, :state => :runnable
    kind :test
    paths ["/foo/1.test", "foo/baz/a.test", "foo/baz/b.test"]
  end

  factory :build_artifact do
    build_attempt
    log_file File.open(FIXTURE_PATH + "build_artifact.log")
  end
end