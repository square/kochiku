require 'spec_helper'
require 'partitioner'

RSpec.shared_examples "Partitioner::Default behavior" do |partitioner_class|
  let(:build) { FactoryBot.create(:build) }
  let(:partitioner) { partitioner_class.new(build, build.kochiku_yml) }

  before do
    allow(GitRepo).to receive(:load_kochiku_yml).and_return(kochiku_yml)
    allow(GitRepo).to receive(:inside_copy).and_yield
  end

  let(:kochiku_yml) do
    {
      "targets" => [
        {
          'type' => 'rspec',
          'glob' => 'spec/**/*_spec.rb',
          'workers' => 3,
          'balance' => rspec_balance,
          'manifest' => rspec_manifest,
          'time_manifest' => rspec_time_manifest,
        },
        {
          'type' => 'cuke',
          'glob' => 'features/**/*.feature',
          'workers' => 3,
          'balance' => cuke_balance,
          'manifest' => cuke_manifest,
          'time_manifest' => cuke_time_manifest,
        }
      ]
    }
  end

  let(:rspec_balance) { 'alphabetically' }
  let(:rspec_manifest) { nil }
  let(:cuke_balance) { 'alphabetically' }
  let(:cuke_manifest) { nil }
  let(:rspec_time_manifest) { nil }
  let(:cuke_time_manifest) { nil }

  describe '#emails_for_commits_causing_failures' do
    subject { partitioner.emails_for_commits_causing_failures }
    it "should return a hash" do
      expect(subject).to be_a(Hash)
    end
  end

  describe '#partitions' do
    subject { partitioner.partitions }

    context "with a kochiku.yml that does not use Ruby" do
      let(:kochiku_yml) do
        {
          "targets" => [
            {
              'type' => 'other',
              'glob' => 'spec/**/*_spec.rb',
              'workers' => 1,
            }
          ]
        }
      end

      it "should not include a ruby version" do
        partitions = subject
        expect(partitions.size).to be(1)
        expect(partitions.first["type"]).to eq("other")
        expect(partitions.first["files"]).not_to be_empty
        expect(partitions.first["options"]).not_to have_key("ruby")
      end
    end

    context "with a ruby-based kochiku.yml" do
      let(:queue_override) { nil }
      let(:retry_count) { nil }
      let(:kochiku_yml) do
        {
          "ruby" => ["ree-1.8.7-2011.12"],
          "targets" => [
            {
              'type' => 'rspec',
              'glob' => 'spec/**/*_spec.rb',
              'workers' => 3,
              'balance' => rspec_balance,
              'manifest' => rspec_manifest,
              'queue_override' => queue_override,
              'retry_count' => retry_count,
            }
          ]
        }
      end

      it "parses options from kochiku yml" do
        partitions = subject
        expect(partitions.first["options"]["ruby"]).to eq("ree-1.8.7-2011.12")
        expect(partitions.first["type"]).to eq("rspec")
        expect(partitions.first["files"]).not_to be_empty
        expect(partitions.first["queue"]).to eq("developer")
        expect(partitions.first["retry_count"]).to eq(0)
        expect(partitions.first['options']).not_to include('log_file_globs')
      end

      context "with a master build" do
        let(:build) { FactoryBot.create(:convergence_branch_build) }

        it "should use the ci queue" do
          expect(build.branch_record).to be_convergence
          expect(subject.first["queue"]).to eq("ci")
        end

        context "with queue_override" do
          let(:queue_override) { "override" }
          it "should override the queue on the build part" do
            expect(subject.first["queue"]).to eq("ci-override")
          end
        end
      end

      context "with a branch build" do
        it "should use the developer queue" do
          expect(build.branch_record).to_not be_convergence
          expect(subject.first["queue"]).to eq("developer")
        end

        context "with queue_override" do
          let(:queue_override) { "override" }
          it "should override the queue on the build part" do
            expect(subject.first["queue"]).to eq("developer-override")
          end
        end

        context "with retry_count" do
          let(:retry_count) { 2 }
          it "should set the retry count" do
            expect(subject.first["retry_count"]).to eq(2)
          end
        end
      end
    end

    context 'with log_file_globs' do
      let(:kochiku_yml) do
        {
          'log_file_globs' => log_files,
          'targets' => [
            {
              'type' => 'other',
              'glob' => 'spec/**/*_spec.rb',
              'workers' => 1,
            }
          ]
        }
      end

      context 'that uses a single string' do
        let(:log_files) { 'mylog.log' }

        it 'puts an array into the options' do
          expect(subject.first['options']['log_file_globs']).to eq(['mylog.log'])
        end
      end

      context 'that uses an array' do
        let(:log_files) { ['mylog.log', 'another.log'] }

        it 'puts the array into the options' do
          expect(subject.first['options']['log_file_globs']).to eq(['mylog.log', 'another.log'])
        end
      end
    end

    context 'with different log_file_globs specified for different targets' do
      let(:kochiku_yml) do
        {
          'targets' => [
            {
              'type' => 'unit',
              'glob' => 'spec/**/*_spec.rb',
              'workers' => 1,
              'log_file_globs' => "log1",
            },
            {
              'type' => 'other',
              'glob' => 'spec/**/*_spec.rb',
              'workers' => 1,
              'log_file_globs' => "log2"
            }
          ]
        }
      end

      it "should parse log_file_globs properly" do
        expect(subject.first['options']['log_file_globs']).to eq(['log1'])
        expect(subject.second['options']['log_file_globs']).to eq(['log2'])
      end
    end

    context 'when the glob matches' do
      before { allow(Dir).to receive(:[]).and_return(matches) }

      context 'no files' do
        let(:matches) { [] }
        it 'does nothing' do
          expect(subject).to eq([])
        end
      end

      context 'one file' do
        let(:matches) { %w(a) }
        it 'makes one partition' do
          expect(subject).to include(a_hash_including({ 'files' => %w(a) }))
        end
      end

      context 'multiple files' do
        let(:matches) { %w(a b c d) }

        # :rspec_balance set to alphabetically above
        it 'using alphabetically' do
          partitions = subject
          expect(partitions).to include(a_hash_including({ 'files' => %w(a b) }))
          expect(partitions).to include(a_hash_including({ 'files' => %w(c) }))
          expect(partitions).to include(a_hash_including({ 'files' => %w(d) }))
        end

        context 'and balance is round_robin' do
          let(:rspec_balance) { 'round_robin' }

          it 'uses round_robin' do
            partitions = subject
            expect(partitions).to include(a_hash_including({ 'files' => %w(a d) }))
            expect(partitions).to include(a_hash_including({ 'files' => %w(b) }))
            expect(partitions).to include(a_hash_including({ 'files' => %w(c) }))
          end

          context 'and a manifest file is specified' do
            before { allow(YAML).to receive(:load_file).with(rspec_manifest).and_return(%w(c b a)) }
            let(:rspec_manifest) { 'manifest.yml' }
            let(:matches) { %w(a b c d) }

            it 'uses the manifest' do
              partitions = subject
              expect(partitions).to include(a_hash_including({ 'files' => %w(c d) }))
              expect(partitions).to include(a_hash_including({ 'files' => %w(a) }))
              expect(partitions).to include(a_hash_including({ 'files' => %w(b) }))
            end
          end

          context 'and time manifest files are specified' do
            before do
              allow(YAML).to receive(:load_file).with(rspec_time_manifest).and_return(
                {
                  'a.spec' => [2],
                  'b.spec' => [5, 8],
                  'c.spec' => [9, 6],
                  'd.spec' => [5, 8],
                  'deleted.spec' => [10],
                }
              )
              allow(YAML).to receive(:load_file).with(cuke_time_manifest).and_return(
                {
                  'f.feature' => [2],
                  'g.feature' => [5, 8],
                  'h.feature' => [6, 9],
                  'i.feature' => [15, 16],
                }
              )
              allow(Dir).to receive(:[]).with("spec/**/*_spec.rb").and_return(spec_matches)
              allow(Dir).to receive(:[]).with("features/**/*.feature").and_return(feature_matches)
            end

            let(:rspec_time_manifest) { 'rspec_time_manifest.yml' }
            let(:cuke_time_manifest) { 'cuke_time_manifest.yml' }
            let(:spec_matches) { %w(a.spec b.spec c.spec d.spec e.spec) }
            let(:feature_matches) { %w(f.feature g.feature h.feature i.feature) }

            it 'should greedily partition files in the time_manifest, and round robin the remaining files' do
              partitions = subject
              expect(partitions).to include(a_hash_including({ 'type' => 'rspec', 'files' => ['c.spec', 'e.spec'] }))
              expect(partitions).to include(a_hash_including({ 'type' => 'rspec', 'files' => ['d.spec', 'a.spec'] }))
              expect(partitions).to include(a_hash_including({ 'type' => 'rspec', 'files' => ['b.spec'] }))
              expect(partitions).to include(a_hash_including({ 'type' => 'cuke', 'files' => ['i.feature'] }))
              expect(partitions).to include(a_hash_including({ 'type' => 'cuke', 'files' => ['h.feature'] }))
              expect(partitions).to include(a_hash_including({ 'type' => 'cuke', 'files' => ['g.feature', 'f.feature']}))
            end
          end
        end

        context 'and balance is size' do
          let(:rspec_balance) { 'size' }

          before do
            allow(File).to receive(:size).with('a').and_return(1)
            allow(File).to receive(:size).with('b').and_return(1000)
            allow(File).to receive(:size).with('c').and_return(100)
            allow(File).to receive(:size).with('d').and_return(10)
          end

          it 'uses size' do
            partitions = subject
            expect(partitions).to include(a_hash_including({ 'files' => %w(b a) }))
            expect(partitions).to include(a_hash_including({ 'files' => %w(c) }))
            expect(partitions).to include(a_hash_including({ 'files' => %w(d) }))
          end
        end

        context 'and balance is size_greedy_partitioning' do
          let(:rspec_balance) { 'size_greedy_partitioning' }

          before do
            allow(File).to receive(:size).with('a').and_return(1)
            allow(File).to receive(:size).with('b').and_return(1000)
            allow(File).to receive(:size).with('c').and_return(100)
            allow(File).to receive(:size).with('d').and_return(10)
          end

          it 'uses greedy_size' do
            partitions = subject
            expect(partitions).to include(a_hash_including({ 'files' => %w(b) }))
            expect(partitions).to include(a_hash_including({ 'files' => %w(c) }))
            expect(partitions).to include(a_hash_including({ 'files' => %w(d a) }))
          end
        end

        context 'and balance is size_average_partitioning' do
          let(:rspec_balance) { 'size_average_partitioning' }

          before do
            allow(File).to receive(:size).with('a').and_return(1)
            allow(File).to receive(:size).with('b').and_return(1000)
            allow(File).to receive(:size).with('c').and_return(100)
            allow(File).to receive(:size).with('d').and_return(10)
          end

          it 'uses size_average' do
            partitions = subject
            expect(partitions).to include(a_hash_including({ 'files' => %w(a b) }))
            expect(partitions).to include(a_hash_including({ 'files' => %w(c) }))
            expect(partitions).to include(a_hash_including({ 'files' => %w(d) }))
          end
        end

        context 'and balance is isolated' do
          let(:rspec_balance) { 'isolated' }

          it 'isolates files' do
            partitions = subject
            expect(partitions).to include(a_hash_including({ 'files' => %w(a) }))
            expect(partitions).to include(a_hash_including({ 'files' => %w(b) }))
            expect(partitions).to include(a_hash_including({ 'files' => %w(c) }))
            expect(partitions).to include(a_hash_including({ 'files' => %w(d) }))
          end
        end
      end
    end

    context 'when target is specified' do
      let(:kochiku_yml) do
        {
          'targets' => [
            {
              'type' => 'instrumentation',
              'target' => 'util:libraryA'
            },
            {
              'type' => 'instrumentation',
              'target' => ['util:libraryB', 'util:libraryC']
            }
          ]
        }
      end

      it 'accepts both strings and arrays' do
        expect(subject.size).to eq(2)
        expect(subject[0]['files']).to eq(['util:libraryA'])
        expect(subject[1]['files']).to eq(['util:libraryB', 'util:libraryC'])
      end

      context "when workers and/or glob are also specified" do
        let(:kochiku_yml) do
          {
            'targets' => [
              {
                'type' => 'instrumentation',
                'target' => 'util:libraryA',
                'workers' => 10,
                'glob' => 'spec/**/*_spec.rb'
              }
            ]
          }
        end

        it 'ignores them' do
          expect(subject.size).to eq(1)
          expect(subject[0]['files']).to eq(['util:libraryA'])
        end
      end
    end
  end
end
