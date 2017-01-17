require 'lib/partitioner/shared_default_behavior'

describe Partitioner::DependencyMap do
  include_examples "Partitioner::Default behavior", Partitioner::DependencyMap

  describe '#partitions' do
    let(:build) { FactoryGirl.create(:build) }
    let(:partitioner) { Partitioner::DependencyMap.new(build, build.kochiku_yml) }

    before do
      allow(GitRepo).to receive(:load_kochiku_yml).and_return(kochiku_yml)
      allow(GitRepo).to receive(:inside_copy).and_yield

      allow(Dir).to receive(:[]) do |*globs|
        matched_files = []

        matched_files << 'source_for_glob_1' if globs.include?('source_glob/1/**')
        matched_files << 'test_for_glob_1' if globs.include?('test_glob/1/**')

        matched_files << 'source_for_glob_2_part_1' if globs.include?('source_glob/2_part_1/**')
        matched_files << 'source_for_glob_2_part_2' if globs.include?('source_glob/2_part_2/**')
        matched_files << 'test_for_glob_2_part_1' if globs.include?('test_glob/2_part_1/**')
        matched_files << 'test_for_glob_2_part_2' if globs.include?('test_glob/2_part_2/**')

        matched_files << 'test_for_default_glob' if globs.include?('test_glob/default/**')

        matched_files << 'generic_glob_match' if globs.include?('glob/**')

        matched_files
      end

      allow(GitBlame).to receive(:net_files_changed_in_branch) do |_build, options|
        if options && options[:glob]
          (Dir[*options[:glob]] & changed_files)
            .map { |file| {:file => file, :emails => []} }
        else
          changed_files.map { |file| {:file => file, :emails => []} }
        end
      end
    end

    let(:changed_files) { [] }

    let(:kochiku_yml) do
      {
        'dependency_map_options' => {
          'run_all_tests_for_branches' => [
            'master'
          ]
        },
        'targets' => [target]
      }
    end

    let(:dependency_map) do
      [
        {
          'source_glob' => 'source_glob/1/**',
          'test_glob' => 'test_glob/1/**'
        },
        {
          'source_glob' => %w(
            source_glob/2_part_1/**
            source_glob/2_part_2/**
          ),
          'test_glob' => %w(
            test_glob/2_part_1/**
            test_glob/2_part_2/**
          )
        }
      ]
    end

    subject(:partitions) { partitioner.partitions }

    context 'when dependency_map is defined' do
      let(:target) do
        {
          'type' => 'karma_chrome',
          'dependency_map' => dependency_map,
          'default_test_glob' => 'test_glob/default/**'
        }
      end

      context 'on a branch where all tests should be run' do
        let(:build) { FactoryGirl.create(:build, :branch_record => FactoryGirl.create(:master_branch)) }

        context 'when one of the source_globs matches changed files' do
          let(:changed_files) { %w(source_for_glob_1) }

          it 'should add all test globs to partition' do
            expect(partitions.first['files']).to(
              eq(%w(test_for_glob_1 test_for_glob_2_part_1 test_for_glob_2_part_2 test_for_default_glob))
            )
          end
        end

        context 'when none of the source_globs match the changed files' do
          let(:changed_files) { %w(does_not_match_any_source) }

          it 'should add all test globs to partition' do
            expect(partitions.first['files']).to(
              eq(%w(test_for_glob_1 test_for_glob_2_part_1 test_for_glob_2_part_2 test_for_default_glob))
            )
          end
        end
      end

      context 'on a branch where tests should be isolated' do
        context 'when kochiku.yml was changed' do
          let(:changed_files) { %w(config/ci/kochiku.yml) }

          it 'should add all test globs to partition' do
            expect(partitions.first['files']).to(
              eq(%w(test_for_glob_1 test_for_glob_2_part_1 test_for_glob_2_part_2 test_for_default_glob))
            )
          end
        end

        context 'when one of the source_globs matches changed files' do
          let(:changed_files) { %w(source_for_glob_1) }

          it 'adds only the tests for that glob to the partition' do
            expect(partitions.first['files']).to eq(%w(test_for_glob_1))
          end
        end

        context 'when multiple source_globs match changed files' do
          let(:changed_files) { %w(source_for_glob_1 source_for_glob_2_part_1) }

          it 'adds the tests for both globs to the partition' do
            expect(partitions.first['files']).to(
              eq(%w(test_for_glob_1 test_for_glob_2_part_1 test_for_glob_2_part_2))
            )
          end
        end

        context 'when none of the source_globs match the changed files' do
          let(:changed_files) { %w(does_not_match_any_source) }

          context 'when default_test_glob is defined' do
            it 'adds only default_test_glob tests to the partition' do
              expect(partitions.first['files']).to eq(%w(test_for_default_glob))
            end
          end

          context 'when default_test_glob is undefined' do
            let(:target) do
              {
                'type' => 'karma_chrome',
                'dependency_map' => dependency_map
              }
            end

            it 'adds no tests to the partition' do
              expect(partitions).to eq([])
            end
          end
        end
      end
    end

    context 'when dependency_map is undefined' do
      context 'when glob is defined' do
        context 'when default_test_glob is undefined' do
          let(:target) do
            {
              'type' => 'karma_chrome',
              'glob' => 'glob/**'
            }
          end

          it 'adds tests from glob to partition' do
            expect(partitions.first['files']).to eq(%w(generic_glob_match))
          end
        end

        context 'when default_test_glob is defined' do
          let(:target) do
            {
              'type' => 'karma_chrome',
              'glob' => 'glob/**',
              'default_test_glob' => 'test_glob/default/**'
            }
          end

          it 'adds tests from default_test_glob to partition' do
            expect(partitions.first['files']).to eq(%w(test_for_default_glob))
          end
        end
      end

      context 'when glob is undefined' do
        context 'when default_test_glob is undefined' do
          let(:target) do
            {
              'type' => 'karma_chrome'
            }
          end

          it 'does not make any partitions' do
            expect(partitions).to eq([])
          end
        end

        context 'when default_test_glob is defined' do
          let(:target) do
            {
              'type' => 'karma_chrome',
              'default_test_glob' => 'test_glob/default/**'
            }
          end

          it 'adds tests from default_test_glob to partition' do
            expect(partitions.first['files']).to eq(%w(test_for_default_glob))
          end
        end
      end
    end
  end
end
