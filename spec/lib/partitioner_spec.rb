require 'spec_helper'

describe Partitioner do
  let(:partitioner) { Partitioner.new }

  before do
    YAML.stub(:load_file).with(Partitioner::BUILD_YML).and_return(build_yml)
    YAML.stub(:load_file).with(Partitioner::KOCHIKU_YML).and_return(kochiku_yml)
    File.stub(:exist?).with(Partitioner::POM_XML).and_return(pom_xml_exists)
    File.stub(:exist?).with(Partitioner::KOCHIKU_YML).and_return(kochiku_yml_exists)
    File.stub(:exist?).with(Partitioner::BUILD_YML).and_return(build_yml_exists)
  end

  let(:build_yml) {{
    'host1' => {
      'type'  => 'rspec',
      'files' => '<FILES>'
    },
    'bad config' => {}
  }}

  let(:kochiku_yml) {[
    { 'type' => 'rspec', 'glob' => 'spec/**/*_spec.rb', 'workers' => 3, 'balance' => balance, 'manifest' => manifest }
  ]}

  let(:pom_xml_exists) { false }
  let(:build_yml_exists) { true }
  let(:balance) { 'alphabetically' }
  let(:manifest) { nil }

  context "when there is no config yml" do
    let(:kochiku_yml_exists) { false }
    it "should return a single partiion" do
      File.stub(:exist?).with(Partitioner::KOCHIKU_YML).and_return(false)
      File.stub(:exist?).with(Partitioner::BUILD_YML).and_return(false)
      partitions = partitioner.partitions
      partitions.size.should == 1
      partitions.first["type"].should == "spec"
      partitions.first["files"].should_not be_empty
    end
  end

  describe '#partitions' do
    subject { partitioner.partitions }

    context 'when there is a pom.xml' do
      let(:kochiku_yml_exists) { false }
      let(:build_yml_exists) { false }
      let(:pom_xml_exists) { true }
      before do
        sample_pom = File.read(Rails.root.join("spec/fixtures/sample_pom.xml"))
        File.stub(:read).with(Partitioner::POM_XML).and_return(sample_pom)
      end

      it "should return a list of targets" do
        partitions = subject
        partitions.size.should == 170
        partitions.each do |partition|
          partition.should have_key("type")
          partition["files"].should_not be_empty
        end
      end
    end

    context 'when there is not a kochiku.yml' do
      let(:kochiku_yml_exists) { false }
      it { should == [{'type' => 'rspec', 'files' => '<FILES>'}] }
    end

    context 'when there is a kochiku.yml' do
      let(:kochiku_yml_exists) { true }

      before { Dir.stub(:[]).and_return(matches) }

      context 'when there are no files matching the glob' do
        let(:matches) { [] }
        it { should == [] }
      end

      context 'when there is one file matching the glob' do
        let(:matches) { %w(a) }
        it { should == [{ 'type' => 'rspec', 'files' => %w(a) }] }
      end

      context 'when there are many files matching the glob' do
        let(:matches) { %w(a b c d) }
        it { should == [
          { 'type' => 'rspec', 'files' => %w(a b) },
          { 'type' => 'rspec', 'files' => %w(c) },
          { 'type' => 'rspec', 'files' => %w(d) },
        ] }

        context 'and balance is round_robin' do
          let(:balance) { 'round_robin' }
          it { should == [
            { 'type' => 'rspec', 'files' => %w(a d) },
            { 'type' => 'rspec', 'files' => %w(b) },
            { 'type' => 'rspec', 'files' => %w(c) },
          ] }

          context 'and a manifest file is specified' do
            before { YAML.stub(:load_file).with(manifest).and_return { %w(c b a) } }
            let(:manifest) { 'manifest.yml' }
            let(:matches) { %w(a b c d) }

            it { should == [
              { 'type' => 'rspec', 'files' => %w(c d) },
              { 'type' => 'rspec', 'files' => %w(b) },
              { 'type' => 'rspec', 'files' => %w(a) },
            ]
            }
          end
        end

        context 'and balance is size' do
          let(:balance) { 'size' }

          before do
            File.stub(:size).with('a').and_return(1)
            File.stub(:size).with('b').and_return(1000)
            File.stub(:size).with('c').and_return(100)
            File.stub(:size).with('d').and_return(10)
          end

          it { should == [
            { 'type' => 'rspec', 'files' => %w(b a) },
            { 'type' => 'rspec', 'files' => %w(c) },
            { 'type' => 'rspec', 'files' => %w(d) },
          ] }
        end

        context 'and balance is size_greedy_partitioning' do
          let(:balance) { 'size_greedy_partitioning' }

          before do
            File.stub(:size).with('a').and_return(1)
            File.stub(:size).with('b').and_return(1000)
            File.stub(:size).with('c').and_return(100)
            File.stub(:size).with('d').and_return(10)
          end

          it { should =~ [
            { 'type' => 'rspec', 'files' => %w(b) },
            { 'type' => 'rspec', 'files' => %w(c) },
            { 'type' => 'rspec', 'files' => %w(d a) },
          ] }
        end

        context 'and balance is size_average_partitioning' do
          let(:balance) { 'size_average_partitioning' }

          before do
            File.stub(:size).with('a').and_return(1)
            File.stub(:size).with('b').and_return(1000)
            File.stub(:size).with('c').and_return(100)
            File.stub(:size).with('d').and_return(10)
          end

          it { should == [
            { 'type' => 'rspec', 'files' => %w(a b) },
            { 'type' => 'rspec', 'files' => %w(c) },
            { 'type' => 'rspec', 'files' => %w(d) },
          ] }
        end

        context 'and balance is isolated' do
          let(:balance) { 'isolated' }

          it { should == [
            { 'type' => 'rspec', 'files' => %w(a) },
            { 'type' => 'rspec', 'files' => %w(b) },
            { 'type' => 'rspec', 'files' => %w(c) },
            { 'type' => 'rspec', 'files' => %w(d) },
          ] }
        end
      end
    end
  end
end
