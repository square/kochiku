FactoryGirl.define do
  factory :branch do
    sequence(:name) {|n| "branch_#{n}" }
    association :repository

    factory :convergence_branch do
      name "1-x-stable"
      convergence true
    end

    factory :master_branch do
      name "master"
      convergence true
    end

    factory :branch_on_disabled_repo do
      association :repository, factory: :disabled_repository
    end
  end

  factory :build do
    state :partitioning
    ref { SecureRandom.hex(20) } # 20 is the length in bytes, resulting string is twice n
    association :branch_record, factory: :branch

    factory :convergence_branch_build do
      association :branch_record, :factory => :convergence_branch
    end

    factory :completed_build do
      state [:failed, :succeeded].sample

      # specify num_build_parts on the factory to create a build with more than 1 build_part
      transient do
        num_build_parts 1
      end

      after(:create) do |build_instance, evaluator|
        create_list(:build_part_with_build_attempt, evaluator.num_build_parts, build_instance: build_instance)
      end
    end

    factory :build_on_disabled_repo do
      association :branch_record, factory: :branch_on_disabled_repo
    end
  end

  factory :build_part do
    association :build_instance, :factory => :build, :state => :runnable
    kind :test
    paths ["/foo/1.test", "foo/baz/a.test", "foo/baz/b.test"]
    queue :ci

    factory :build_part_with_build_attempt do
      after(:create) do |build_part, evaluator|
        create_list(:completed_build_attempt, 1, build_part: build_part)
      end
    end
  end

  factory :build_attempt do
    build_part
    state :runnable

    factory :completed_build_attempt do
      state { build_part.build_instance.state == :succeeded ? :passed : :failed }
      finished_at { Time.current }
    end
  end

  factory :build_artifact do
    association :build_attempt, :state => :failed
    log_file File.open(FIXTURE_PATH + "build_artifact.log")

    factory :stdout_build_artifact do
      log_file File.open(FIXTURE_PATH + "stdout.log")
    end
  end

  factory :repository do
    sequence(:url) { |n| "git@github.com:org_name/test-repo#{n}.git" } # these repos do not exist on purpose
    test_command "script/ci worker"
    on_green_update 'last-green-build'
    allows_kochiku_merges true
    enabled true

    factory :stash_repository do
      sequence(:url) { |n| "git@stash.example.com:bucket_name/test-repo#{n}.git" }
    end

    factory :disabled_repository do
      enabled false
    end
  end
end
