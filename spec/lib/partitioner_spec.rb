require 'spec_helper'

describe Partitioner do
  let(:partitioner) { Partitioner.new(config) }

  let(:config) {[
    { 'type' => 'rspec', 'glob' => 'spec/**/*_spec.rb', 'workers' => 3 }
  ]}

  describe '#partitions' do
    before { Dir.stub(:[]).and_return(matches) }

    subject { partitioner.partitions }

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
        { 'type' => 'rspec', 'files' => %w(a b c d e f) },
        { 'type' => 'rspec', 'files' => %w(g h i j k) },
        { 'type' => 'rspec', 'files' => %w(l m n o p) },
      ] }
    end
  end
end
