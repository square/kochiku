require 'spec_helper'

describe BuildPartitioningJob do
  before do
    @build = Build.create!(:project => projects(:big_rails_app), :ref => "asdfgh", :state => :runnable, :queue => :ci)
  end

  describe "#perform" do
    context "when error" do
      it "should set the build state to error" do
        GitRepo.should_receive(:inside_copy).and_raise(NameError)
        expect {
          BuildPartitioningJob.perform(@build.id)
        }.to raise_error(NameError)

        @build.reload.state.should == :error

      end
    end
  end

end
