require 'spec_helper'

describe BuildPartitioningJob do
  before do
    @build = FactoryGirl.create(:build, :state => :runnable)
  end

  describe "#perform" do
    context "when an error occurs" do
      it "should set the build state to error" do
        GitRepo.should_receive(:inside_copy).and_raise(NameError)
        expect {
          BuildPartitioningJob.perform(@build.id)
        }.to raise_error(NameError)

        @build.reload.state.should == :errored
      end
    end
  end

end
