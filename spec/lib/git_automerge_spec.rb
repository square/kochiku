require 'spec_helper'

describe GitAutomerge do
  describe "#automerge" do
    let(:project) { FactoryGirl.create(:big_rails_project) }
    let(:build) { FactoryGirl.create(:build, :project => project) }
    let(:merger) { GitAutomerge.new }

    subject { merger.automerge(build) }

    before(:each) { @stubber = CommandStubber.new }

    context "when merge succeeds" do
      it "should not raise exceptions" do
        combined_log = subject
        combined_log.should include(@stubber.fake_command_output)
        @stubber.check_cmd_executed("git merge")
      end
    end

    context "when merge fails due to merge conflicts" do
      before(:each) { @stubber.stub_capture2e_failure("git merge") }

      it "should raise an exception" do
        expect { subject }.to raise_error(GitAutomerge::UnableToMergeError)
      end
    end

    context "when push fails" do
      before(:each) { @stubber.stub_capture2e_failure("git push") }

      it "should raise an exception" do
        expect { subject }.to raise_error(GitAutomerge::UnableToMergeError)
        @stubber.check_cmd_executed("git pull --rebase")
        @stubber.check_cmd_executed("git push origin master")
      end
    end
  end
end
