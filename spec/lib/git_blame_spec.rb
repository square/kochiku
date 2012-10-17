require 'spec_helper'

describe GitBlame do
  let(:project) { FactoryGirl.create(:big_rails_project) }
  let(:build) { FactoryGirl.create(:build, :project => project) }

  describe "#emails_of_build_breakers" do
    context "with one user" do
      before do
        GitBlame.stub(:fetch_name_email_pairs).and_return("User One:userone@example.com")
      end

      it "returns the email of the user" do
        GitBlame.emails_of_build_breakers(build).should == ["userone@example.com"]
      end
    end

    context "with two users" do
      before do
        GitBlame.stub(:fetch_name_email_pairs).and_return("User One:userone@example.com\nUser Two:usertwo@example.com")
      end

      it "returns the emails of the users" do
        GitBlame.emails_of_build_breakers(build).should == ["userone@example.com", "usertwo@example.com"]
      end
    end
  end
end