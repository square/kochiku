require 'spec_helper'

describe BuildPartitioningJob do

  describe "#perform" do
    subject { BuildPartitioningJob.perform(id) }
    let(:id) { build.id }
    let(:build) { FactoryGirl.create(:build, :state => :runnable) }
    before do
      allow(GitRepo).to receive(:load_kochiku_yml).and_return(nil)
    end

    context "with a job runs successfully" do
      before do
        allow(GitRepo).to receive(:inside_copy).and_yield
        allow(Build).to receive(:find).with(id).and_return(build)
        allow(Partitioner).to receive(:for_build).with(build).and_return(partitioner)
        allow(partitioner).to receive(:partitions).and_return('PARTITIONS')
        allow(build).to receive(:partition).with('PARTITIONS')
      end

      let(:partitioner) { double }

      it "uses the partitioner to partition the build" do
        stub_request(:post, %r{#{build.repository.base_api_url}/statuses/})
        expect(partitioner).to receive(:partitions).and_return('PARTITIONS')
        expect(build).to receive(:partition).with('PARTITIONS')

        subject
      end

      it "with a pull request marks a build as pending" do
        stub_request(:post, "#{build.repository.base_api_url}/statuses/#{build.ref}").with do |request|
          expect(request.headers["Authorization"]).to eq("token #{GithubRequest::OAUTH_TOKEN}")
          body = JSON.parse(request.body)
          expect(body["state"]).to eq("pending")
          expect(body["description"]).not_to be_blank
          expect(body["target_url"]).not_to be_blank
          true
        end
        subject
      end
    end

    context "no test_command specified" do
      before do
        build.repository.update!(test_command: nil)
      end

      it "raises an error and fails build" do
        subject
        build.reload
        expect(build.error_details[:message]).to include("No test_command")
        expect(build.build_parts.size).to eq(0)
      end
    end

    context "when a non-retryable error occurs" do
      error_message = "A name error occurred"
      before { allow(GitRepo).to receive(:load_kochiku_yml).and_raise(NameError.new(error_message)) }

      it "should re-raise the error and set the build state to errored" do
        expect { subject }.to raise_error(NameError)
        build.reload
        expect(build.state).to eq(:errored)
        expect(build.error_details[:message]).to eq(error_message)
        expect(build.error_details[:backtrace]).not_to be_blank
      end
    end

    context "when a retryable error occurs" do
      before { allow(GitRepo).to receive(:load_kochiku_yml).and_raise(GitRepo::RefNotFoundError) }

      it "should re-raise the error and set the build state to waiting for sync" do
        expect { subject }.to raise_error(GitRepo::RefNotFoundError)
        expect(build.reload.state).to eq(:waiting_for_sync)
      end
    end

    it "should have an on_failure_retry hook that will re-enqueue the job if it it gets a git ref not found error" do
      expect(Resque).to receive(:enqueue_in).with(60, BuildPartitioningJob, id)
      BuildPartitioningJob.on_failure_retry(GitRepo::RefNotFoundError.new, id)
    end
  end
end
