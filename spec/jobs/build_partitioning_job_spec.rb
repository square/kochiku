require 'spec_helper'

describe BuildPartitioningJob do

  describe "#perform" do
    subject { BuildPartitioningJob.perform(id) }

    let(:id)    { build.id }
    let(:build) { FactoryGirl.create(:build, :state => :runnable) }

    it "uses the partitioner to partition the build" do
      partitioner = stub

      GitRepo.stub(:inside_copy).and_yield
      Build.stub(:find).with(id).and_return(build)
      Partitioner.stub(:new).and_return(partitioner)

      partitioner.should_receive(:partitions).and_return('PARTITIONS')
      build.should_receive(:partition).with('PARTITIONS')

      subject
    end

    context "when an error occurs" do
      before { GitRepo.stub(:inside_copy).and_raise(NameError) }

      it "should re-raise the error and set the build state to errored" do
        expect { subject }.to raise_error(NameError)
        build.reload.state.should == :errored
      end
    end
  end
end
