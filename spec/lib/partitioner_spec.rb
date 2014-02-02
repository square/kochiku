require 'spec_helper'

describe Partitioner do
  let(:build) { FactoryGirl.create(:build) }
  let(:partitioner) { Partitioner.new }

  before do
    allow(YAML).to receive(:load_file).with(Partitioner::KOCHIKU_YML_LOC_2).and_return(kochiku_yml)
    allow(File).to receive(:exist?).with(Partitioner::KOCHIKU_YML_LOC_1).and_return(false) # always use loc_2 in the specs
    allow(File).to receive(:exist?).with(Partitioner::KOCHIKU_YML_LOC_2).and_return(kochiku_yml_exists)
  end

  let(:kochiku_yml) {
    [
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

  let(:kochiku_yml_exists) { false }
  let(:pom_xml_exists) { false }
  let(:rspec_balance) { 'alphabetically' }
  let(:rspec_manifest) { nil }
  let(:cuke_balance) { 'alphabetically' }
  let(:cuke_manifest) { nil }
  let(:rspec_time_manifest) { nil }
  let(:cuke_time_manifest) { nil }

  context "with a kochiku.yml that does not use Ruby" do
    let(:kochiku_yml_exists) { true }
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
      partitions = partitioner.partitions(build)
      expect(partitions.size).to be(1)
      expect(partitions.first["type"]).to eq("other")
      expect(partitions.first["files"]).not_to be_empty
      expect(partitions.first["options"]).not_to have_key("ruby")
    end
  end


  context "with a ruby-based kochiku.yml" do
    let(:kochiku_yml_exists) { true }
    let(:append_type_to_queue) { nil }
    let(:queue_override) { nil }
    let(:retry_count) { nil }
    let(:kochiku_yml) do
      {
        "ruby" => ["ree-1.8.7-2011.12"],
        "language" => "ruby",
        "targets" => [
          {
            'type' => 'rspec',
            'glob' => 'spec/**/*_spec.rb',
            'workers' => 3,
            'balance' => rspec_balance,
            'manifest' => rspec_manifest,
            'append_type_to_queue' => append_type_to_queue,
            'queue_override' => queue_override,
            'retry_count' => retry_count,
          }
        ]
      }
    end

    it "parses options from kochiku yml" do
      partitions = partitioner.partitions(build)
      expect(partitions.first["options"]["language"]).to eq("ruby")
      expect(partitions.first["options"]["ruby"]).to eq("ree-1.8.7-2011.12")
      expect(partitions.first["type"]).to eq("rspec")
      expect(partitions.first["files"]).not_to be_empty
      expect(partitions.first["queue"]).to eq("developer")
      expect(partitions.first["retry_count"]).to eq(0)
    end

    context "with a master build" do
      let(:build) { FactoryGirl.create(:main_project_build) }

      it "should use the ci queue" do
        expect(build.project).to be_main
        partitions = partitioner.partitions(build)
        expect(partitions.first["queue"]).to eq("ci")
      end

      context "when append_type_to_queue is in kochiku.yml" do
        let(:append_type_to_queue) { true }

        it "should append the type" do
          partitions = partitioner.partitions(build)
          expect(partitions.first["queue"]).to eq("ci-rspec")
        end
      end
    end

    context "with a branch build" do
      it "should use the developer queue" do
        expect(build.project).to_not be_main
        partitions = partitioner.partitions(build)
        expect(partitions.first["queue"]).to eq("developer")
      end

      context "when append_type_to_queue is in kochiku.yml" do
        let(:append_type_to_queue) { true }

        it "should append the type" do
          partitions = partitioner.partitions(build)
          expect(partitions.first["queue"]).to eq("developer-rspec")
        end
      end
    end

    context "with queue_override" do
      let(:queue_override) { "override" }
      it "should override the queue on the build part" do
        partitions = partitioner.partitions(build)
        expect(partitions.first["queue"]).to eq("override")
      end

      context "with append_type_to_queue true" do
        let(:append_type_to_queue) { true }
        it "should override the queue on the build part" do
          partitions = partitioner.partitions(build)
          expect(partitions.first["queue"]).to eq("override")
        end
      end
    end

    context "with retry_count" do
      let(:retry_count) { 2 }
      it "should set the retry count" do
        partitions = partitioner.partitions(build)
        expect(partitions.first["retry_count"]).to eq(2)
      end
    end
  end

  context "when there is no kochiku yml" do
    let(:kochiku_yml_exists) { false }

    it "should return a single partiion" do
      partitions = partitioner.partitions(build)
      expect(partitions.size).to eq(1)
      expect(partitions.first["type"]).to eq("spec")
      expect(partitions.first["files"]).not_to be_empty
    end
  end

  describe '#partitions' do
    subject { partitioner.partitions(build) }

    context 'when there is not a kochiku.yml' do
      let(:kochiku_yml_exists) { false }
      it { should == [{"type" => "spec", "files" => ['no-manifest'], 'queue' => 'developer', 'retry_count' => 0}] }
    end

    context 'when there is a kochiku.yml' do
      let(:kochiku_yml_exists) { true }

      before { allow(Dir).to receive(:[]).and_return(matches) }

      context 'when there are no files matching the glob' do
        let(:matches) { [] }
        it { should == [] }
      end

      context 'when there is one file matching the glob' do
        let(:matches) { %w(a) }
        it { [{ 'type' => 'rspec', 'files' => %w(a), 'queue' => 'developer', 'retry_count' => 0 }].each { |partition| should include(partition) } }
      end

      context 'when there are many files matching the glob' do
        let(:matches) { %w(a b c d) }
        it {
          [
            { 'type' => 'rspec', 'files' => %w(a b), 'queue' => 'developer', 'retry_count' => 0 },
            { 'type' => 'rspec', 'files' => %w(c), 'queue' => 'developer', 'retry_count' => 0 },
            { 'type' => 'rspec', 'files' => %w(d), 'queue' => 'developer', 'retry_count' => 0 },
          ].each { |partition| should include(partition) }
        }

        context 'and balance is round_robin' do
          let(:rspec_balance) { 'round_robin' }
          it {
            [
              { 'type' => 'rspec', 'files' => %w(a d), 'queue' => 'developer', 'retry_count' => 0 },
              { 'type' => 'rspec', 'files' => %w(b), 'queue' => 'developer', 'retry_count' => 0 },
              { 'type' => 'rspec', 'files' => %w(c), 'queue' => 'developer', 'retry_count' => 0 },
            ].each { |partition| should include(partition) }
          }

          context 'and a manifest file is specified' do
            before { allow(YAML).to receive(:load_file).with(rspec_manifest).and_return(%w(c b a)) }
            let(:rspec_manifest) { 'manifest.yml' }
            let(:matches) { %w(a b c d) }

            it {
              [
                { 'type' => 'rspec', 'files' => %w(c d), 'queue' => 'developer', 'retry_count' => 0 },
                { 'type' => 'rspec', 'files' => %w(b), 'queue' => 'developer', 'retry_count' => 0 },
                { 'type' => 'rspec', 'files' => %w(a), 'queue' => 'developer', 'retry_count' => 0 },
              ].each { |partition| should include(partition) }
            }
          end

          context 'and time manifest files are specified' do
            before do allow(YAML).to receive(:load_file).with(rspec_time_manifest).and_return(
                {
                  'a' => [2],
                  'b' => [5, 8],
                  'c' => [6, 9],
                  'd' => [5, 8],
                }
              )
            end

            before do allow(YAML).to receive(:load_file).with(cuke_time_manifest).and_return(
              {
                'f' => [2],
                'g' => [5, 8],
                'h' => [6, 9],
                'i' => [15, 16],
              }
            )
            end

            let(:rspec_time_manifest) { 'rspec_time_manifest.yml' }
            let(:cuke_time_manifest) { 'cuke_time_manifest.yml' }
            let(:matches) { %w(a b c d e) }

            it 'should greedily partition files in the time_manifest, and round robin the remaining files' do
              [
                {'type' => 'rspec', 'files' => ['e'], 'queue' => 'developer', 'retry_count' => 0},
                {'type' => 'rspec', 'files' => ['c', 'd'], 'queue' => 'developer', 'retry_count' => 0},
                {'type' => 'rspec', 'files' => ['b', 'a'], 'queue' => 'developer', 'retry_count' => 0},
                {'type' => 'cuke', 'files' => ['a', 'b'], 'queue' => 'developer', 'retry_count' => 0},
                {'type' => 'cuke', 'files' => ['c', 'd'], 'queue' => 'developer', 'retry_count' => 0},
                {'type' => 'cuke', 'files' => ['e'], 'queue' => 'developer', 'retry_count' => 0},
                {'type' => 'cuke', 'files' => ['i'], 'queue' => 'developer', 'retry_count' => 0},
                {'type' => 'cuke', 'files' => ['h', 'g', 'f'], 'queue' => 'developer', 'retry_count' => 0}
              ].each { |partition| should include(partition) }
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

          it {
            [
              { 'type' => 'rspec', 'files' => %w(b a), 'queue' => 'developer', 'retry_count' => 0 },
              { 'type' => 'rspec', 'files' => %w(c), 'queue' => 'developer', 'retry_count' => 0 },
              { 'type' => 'rspec', 'files' => %w(d), 'queue' => 'developer', 'retry_count' => 0 },
            ].each { |partition| should include(partition) }
          }
        end

        context 'and balance is size_greedy_partitioning' do
          let(:rspec_balance) { 'size_greedy_partitioning' }

          before do
            allow(File).to receive(:size).with('a').and_return(1)
            allow(File).to receive(:size).with('b').and_return(1000)
            allow(File).to receive(:size).with('c').and_return(100)
            allow(File).to receive(:size).with('d').and_return(10)
          end

          it {
            [
              { 'type' => 'rspec', 'files' => %w(b), 'queue' => 'developer', 'retry_count' => 0 },
              { 'type' => 'rspec', 'files' => %w(c), 'queue' => 'developer', 'retry_count' => 0 },
              { 'type' => 'rspec', 'files' => %w(d a), 'queue' => 'developer', 'retry_count' => 0 },
            ].each { |partition| should include(partition) }
          }
        end

        context 'and balance is size_average_partitioning' do
          let(:rspec_balance) { 'size_average_partitioning' }

          before do
            allow(File).to receive(:size).with('a').and_return(1)
            allow(File).to receive(:size).with('b').and_return(1000)
            allow(File).to receive(:size).with('c').and_return(100)
            allow(File).to receive(:size).with('d').and_return(10)
          end

          it {
            [
              { 'type' => 'rspec', 'files' => %w(a b), 'queue' => 'developer', 'retry_count' => 0 },
              { 'type' => 'rspec', 'files' => %w(c), 'queue' => 'developer', 'retry_count' => 0 },
              { 'type' => 'rspec', 'files' => %w(d), 'queue' => 'developer', 'retry_count' => 0 },
            ].each { |partition| should include(partition) }
          }
        end

        context 'and balance is isolated' do
          let(:rspec_balance) { 'isolated' }

          it {
            [
              { 'type' => 'rspec', 'files' => %w(a), 'queue' => 'developer', 'retry_count' => 0 },
              { 'type' => 'rspec', 'files' => %w(b), 'queue' => 'developer', 'retry_count' => 0 },
              { 'type' => 'rspec', 'files' => %w(c), 'queue' => 'developer', 'retry_count' => 0 },
              { 'type' => 'rspec', 'files' => %w(d), 'queue' => 'developer', 'retry_count' => 0 },
            ].each { |partition| should include(partition) }
          }
        end
      end
    end
  end
end
