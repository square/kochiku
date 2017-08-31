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

        matched_files << 'source_glob/1/foo.rb' if globs.include?('source_glob/1/**')
        matched_files << 'test_glob/1/bar_spec.rb' if globs.include?('test_glob/1/**')

        matched_files << 'source_glob/2_part_1/foo.rb' if globs.include?('source_glob/2_part_1/**')
        matched_files << 'source_glob/2_part_2/foo.rb' if globs.include?('source_glob/2_part_2/**')
        matched_files << 'test_glob/2_part_1/bar_spec.rb' if globs.include?('test_glob/2_part_1/**')
        matched_files << 'test_glob/2_part_2/bar_spec.rb' if globs.include?('test_glob/2_part_2/**')

        matched_files << 'test_glob/default/foo/bar/baz_spec.rb' if globs.include?('test_glob/default/**')

        matched_files << 'glob/foo/bar.rb' if globs.include?('glob/**')

        matched_files
      end

      allow(GitBlame).to receive(:net_files_changed_in_branch) do
        changed_files.map { |file| {:file => file, :emails => []} }
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
          let(:changed_files) { %w(source_glob/1/foo.rb) }

          it 'should add all test globs to partition' do
            expect(partitions.first['files']).to(
              eq(%w(test_glob/1/bar_spec.rb test_glob/2_part_1/bar_spec.rb test_glob/2_part_2/bar_spec.rb test_glob/default/foo/bar/baz_spec.rb))
            )
          end
        end

        context 'when none of the source_globs match the changed files' do
          let(:changed_files) { %w(does_not_match_any_source) }

          it 'should add all test globs to partition' do
            expect(partitions.first['files']).to(
              eq(%w(test_glob/1/bar_spec.rb test_glob/2_part_1/bar_spec.rb test_glob/2_part_2/bar_spec.rb test_glob/default/foo/bar/baz_spec.rb))
            )
          end
        end
      end

      context 'on a branch where tests should be isolated' do
        context 'when one of the source_globs matches changed files' do
          let(:changed_files) { %w(source_glob/1/foo.rb) }

          it 'adds only the tests for that glob to the partition' do
            expect(partitions.first['files']).to eq(%w(test_glob/1/bar_spec.rb))
          end

          context 'but no test_glob is provided' do
            let(:dependency_map) do
              [
                {
                  'source_glob' => 'source_glob/1/**'
                }
              ]
            end

            it 'does not add any partitions' do
              expect(partitions).to eq([])
            end
          end

        end

        context 'when multiple source_globs match changed files' do
          let(:changed_files) { %w(source_glob/1/foo.rb source_glob/2_part_1/foo.rb) }

          it 'adds the tests for both globs to the partition' do
            expect(partitions.first['files']).to(
              eq(%w(test_glob/1/bar_spec.rb test_glob/2_part_1/bar_spec.rb test_glob/2_part_2/bar_spec.rb))
            )
          end
        end

        context 'when none of the source_globs match the changed files' do
          let(:changed_files) { %w(does_not_match_any_source) }

          context 'when default_test_glob is defined' do
            it 'adds only default_test_glob tests to the partition' do
              expect(partitions.first['files']).to eq(%w(test_glob/default/foo/bar/baz_spec.rb))
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

        context 'when workers are defined for the maps' do
          let(:target) do
            {
              'type' => 'karma_chrome',
              'workers' => 5,
              'dependency_map' => dependency_map
            }
          end

          let(:dependency_map) do
            [
              {
                'source_glob' => 'source_glob/1/**',
                'test_glob' => 'test_glob/1/**',
                'workers' => 1
              },
              {
                'source_glob' => %w(
                  source_glob/2_part_1/**
                  source_glob/2_part_2/**
                ),
                'test_glob' => %w(
                  test_glob/2_part_1/**
                  test_glob/2_part_2/**
                ),
                'workers' => 1
              }
            ]
          end

          context 'when one of the source_globs matches changed files' do
            let(:changed_files) { %w(source_glob/1/foo.rb) }

            it 'creates partitions for the number of workers specified by that mapping' do
              expect(partitions.size).to eq(1)
            end
          end

          context 'when multiple source_globs match changed files' do
            let(:changed_files) { %w(source_glob/1/foo.rb source_glob/2_part_1/foo.rb) }

            it 'creates partitions for the sum of the workers specified by those mappings' do
              expect(partitions.size).to eq(2)
            end

            context 'and the max workers for the target is less than the sum of those workers' do
              let(:target) do
                {
                  'type' => 'karma_chrome',
                  'workers' => 1,
                  'dependency_map' => dependency_map
                }
              end

              it 'creates partitions for the max workers specified by the target' do
                expect(partitions.size).to eq(1)
              end
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
            expect(partitions.first['files']).to eq(%w(glob/foo/bar.rb))
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
            expect(partitions.first['files']).to eq(%w(test_glob/default/foo/bar/baz_spec.rb))
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
            expect(partitions.first['files']).to eq(%w(test_glob/default/foo/bar/baz_spec.rb))
          end
        end
      end
    end
  end
end
