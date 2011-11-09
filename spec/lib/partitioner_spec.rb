require 'spec_helper'

describe Partitioner do
  let(:partitioner) { Partitioner.new }

  before do
    YAML.stub(:load_file).with(Partitioner::BUILD_YML).and_return(build_yml)
    YAML.stub(:load_file).with(Partitioner::KOCHIKU_YML).and_return(kochiku_yml)
    File.stub(:exist?).with(Partitioner::KOCHIKU_YML).and_return(kochiku_yml_exists)
  end

  let(:build_yml) {{
    'host1' => {
      'type'  => 'rspec',
      'files' => '<FILES>'
    },
    'bad config' => {}
  }}

  let(:kochiku_yml) {[
    { 'type' => 'rspec', 'glob' => 'spec/**/*_spec.rb', 'workers' => 3 }
  ]}

  describe '#partitions' do
    subject { partitioner.partitions }

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
        let(:matches) { %w(a b c d e f g h i j k l m n o p) }
        it { should == [
          { 'type' => 'rspec', 'files' => %w(a d g j m p) },
          { 'type' => 'rspec', 'files' => %w(b e h k n) },
          { 'type' => 'rspec', 'files' => %w(c f i l o) },
        ] }
      end
    end
  end
end
