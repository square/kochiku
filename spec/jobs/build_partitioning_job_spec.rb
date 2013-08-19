require 'spec_helper'

describe BuildPartitioningJob do

  describe "#perform" do
    subject { BuildPartitioningJob.perform(id) }
    let(:id) { build.id }
    let(:build) { FactoryGirl.create(:build, :state => :runnable) }

    context "with a job runs successfully" do
      before do
        GitRepo.stub(:inside_copy).and_yield
        Build.stub(:find).with(id).and_return(build)
        Partitioner.stub(:new).and_return(partitioner)
        partitioner.stub(:partitions).and_return('PARTITIONS')
        build.stub(:partition).with('PARTITIONS')
      end

      let(:partitioner) { double }

      it "uses the partitioner to partition the build" do
        stub_request(:post, %r{#{build.repository.base_api_url}/statuses/})
        partitioner.should_receive(:partitions).and_return('PARTITIONS')
        build.should_receive(:partition).with('PARTITIONS')

        subject
      end

      it "with a pull request marks a build as pending" do
        stub_request(:post, "#{build.repository.base_api_url}/statuses/#{build.ref}").with do |request|
          request.headers["Authorization"].should == "token #{GithubRequest::OAUTH_TOKEN}"
          body = JSON.parse(request.body)
          body["state"].should == "pending"
          body["description"].should_not be_blank
          body["target_url"].should_not be_blank
          true
        end
        subject
      end
    end

    context "when a no retryable error occurs" do
      before { GitRepo.stub(:inside_copy).and_raise(NameError) }

      it "should re-raise the error and set the build state to errored" do
        expect { subject }.to raise_error(NameError)
        build.reload.state.should == :errored
      end
    end

    context "when a retryable error occurs" do
      before { GitRepo.stub(:inside_copy).and_raise(GitRepo::RefNotFoundError) }

      it "should re-raise the error and set the build state to waiting for sync" do
        expect { subject }.to raise_error(GitRepo::RefNotFoundError)
        build.reload.state.should == :waiting_for_sync
      end
    end

    it "should have an on_failure_retry hook that will re-enqueue the job if it it gets a git ref not found error" do
      Resque.should_receive(:enqueue_in).with(60, BuildPartitioningJob, id)
      BuildPartitioningJob.on_failure_retry(GitRepo::RefNotFoundError.new, id)
    end
  end
end
