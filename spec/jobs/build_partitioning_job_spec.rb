require 'spec_helper'

describe BuildPartitioningJob do

  describe "#perform" do
    subject { BuildPartitioningJob.perform(id) }
    let(:id)    { build.id }
    let(:build) { FactoryGirl.create(:build, :state => :runnable) }

    context "with a job runs successfully" do
      before do
        GitRepo.stub(:inside_copy).and_yield
        Build.stub(:find).with(id).and_return(build)
        Partitioner.stub(:new).and_return(partitioner)
        partitioner.stub(:partitions).and_return('PARTITIONS')
        build.stub(:partition).with('PARTITIONS')
      end

      let(:partitioner) { stub }

      it "uses the partitioner to partition the build" do
        stub_request(:post, /https:\/\/git\.squareup\.com\/api\/v3\/repos\/square\/kochiku\/statuses\//)
        partitioner.should_receive(:partitions).and_return('PARTITIONS')
        build.should_receive(:partition).with('PARTITIONS')

        subject
      end

      it "with a pull request marks a build as pending" do
        stub_request(:post, "https://git.squareup.com/api/v3/repos/square/kochiku/statuses/#{build.ref}").with do |request|
          request.headers["Authorization"].should == "token #{GithubCommitStatus::OAUTH_TOKEN}"
          body = JSON.parse(request.body)
          body["state"].should == "pending"
          body["description"].should_not be_blank
          body["target_url"].should_not be_blank
          true
        end
        subject
      end
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
