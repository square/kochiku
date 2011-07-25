FactoryGirl.define do
  factory :project do
    sequence(:name) {|n| "Project ##{n}" }
  end

  factory :build do
    project
    state :partitioning
    queue :ci
    ref { ActiveSupport::SecureRandom.hex }
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
end