require 'spec_helper'

describe GitBlame do
  let(:project) { FactoryGirl.create(:big_rails_project) }
  let(:build) { FactoryGirl.create(:build, :project => project) }

  describe "#emails_of_build_breakers" do
    subject { GitBlame.emails_of_build_breakers(build) }

    after do
      GitBlame.instance_variable_set(:@people_lookup, nil)
    end

    context "with many build breakers" do
      before do
        GitBlame.stub(:git_names_and_emails_since_last_green).and_return("User One:userone@example.com\nUser Two:usertwo@example.com")
        GitBlame.stub(:people_from_ldap).and_return([{"First" => "User", "Last" => "One", "Email" => "userone@example.com"},
                                                     {"First" => "User", "Last" => "Two", "Email" => "usertwo@example.com"}])
      end

      it "returns the emails of the users" do
        subject.should == ["userone@example.com", "usertwo@example.com"]
      end

      it "will only return an email if it is in the ldap list of names and emails" do
        GitBlame.stub(:people_from_ldap).and_return([{"First" => "User", "Last" => "Two", "Email" => "usertwo@example.com"}])
        subject.should == ["usertwo@example.com"]
      end

      it "will not return the same user twice" do
        GitBlame.stub(:git_names_and_emails_since_last_green).and_return("User One:userone@example.com\nUser One:userone@example.com")
        subject.should == ["userone@example.com"]
      end
    end

    context "when the email does not point to a user" do
      before do
        GitBlame.stub(:people_from_ldap).and_return([{"First" => "User", "Last" => "One", "Email" => "userone@example.com", "Username" => "usero"},
                                                     {"First" => "User", "Last" => "Two", "Email" => "usertwo@example.com", "Username" => "usert"},
                                                     {"First" => "User", "Last" => "Three", "Email" => "userthree@example.com", "Username" => "userth"}])
      end

      it "should look up the users by their names" do
        GitBlame.stub(:git_names_and_emails_since_last_green).and_return("User Two:git+ut@git.squareup.com")
        subject.should == ["usertwo@example.com"]
      end

      it "returns the emails of all users mentioned by name with and" do
        GitBlame.stub(:git_names_and_emails_since_last_green).and_return("User One and User Two:git+uo+ut@git.squareup.com")
        subject.should == ["userone@example.com", "usertwo@example.com"]
      end

      it "returns the emails of all users mentioned by name with +" do
        GitBlame.stub(:git_names_and_emails_since_last_green).and_return("User One + User Two:git+uo+ut@git.squareup.com")
        subject.should == ["userone@example.com", "usertwo@example.com"]
      end

      it "returns the emails of all users mentioned by name with 'and' and an oxford comma" do
        GitBlame.stub(:git_names_and_emails_since_last_green).and_return("User One, and User Two:git+uo+ut@git.squareup.com")
        subject.should =~ ["userone@example.com", "usertwo@example.com"]
      end

      it "returns the emails of all users mentioned by name with a combination of 'and' and ','" do
        GitBlame.stub(:git_names_and_emails_since_last_green).and_return("User One, User Two, and User Three:git+uo+ut+ut@git.squareup.com")
        subject.should =~ ["userone@example.com", "usertwo@example.com", "userthree@example.com"]
      end

      it "should lookup the email based on the username" do
        GitBlame.stub(:git_names_and_emails_since_last_green).and_return("First Last:git+usero@git.squareup.com")
        subject.should == ["userone@example.com"]
      end

      it "should send emails to usernames and emails" do
        GitBlame.stub(:git_names_and_emails_since_last_green).and_return("User Two:git+usero@git.squareup.com")
        subject.should =~ ["userone@example.com", "usertwo@example.com"]
      end
    end
  end
end