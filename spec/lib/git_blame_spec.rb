require 'spec_helper'

describe GitBlame do
  let(:project) { FactoryGirl.create(:big_rails_project) }
  let(:build) { FactoryGirl.create(:build, :project => project) }

  describe "#emails_since_last_green" do
    subject { GitBlame.emails_since_last_green(build) }

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

  describe "#emails_in_branch" do
    subject { GitBlame.emails_in_branch(build) }

    after do
      GitBlame.instance_variable_set(:@people_lookup, nil)
    end

    context "with many build breakers" do
      before do
        GitBlame.stub(:git_names_and_emails_in_branch).and_return("User One:userone@example.com\nUser Two:usertwo@example.com")
        GitBlame.stub(:people_from_ldap).and_return([{"First" => "User", "Last" => "One", "Email" => "userone@example.com"},
                                                     {"First" => "User", "Last" => "Two", "Email" => "usertwo@example.com"}])
      end

      it "returns the emails of the users" do
        subject.should == ["userone@example.com", "usertwo@example.com"]
      end
    end
  end

  describe "#changes_since_last_green" do
    subject { GitBlame.changes_since_last_green(build) }

    before do
      GitBlame.unstub(:changes_since_last_green)
    end

    it "should parse the git log message and return a hash of information" do
      GitRepo.stub(:inside_repo).and_return("::!::817b88be7488cab5e4f9d9975222db80d8bceb3b|User One <github+uo@squareup.com>|Fri Oct 19 17:43:47 2012 -0700|this is my commit message::!::")
      git_changes = subject
      git_changes.first[:hash].should == "817b88be7488cab5e4f9d9975222db80d8bceb3b"
      git_changes.first[:author].should == "User One <github+uo@squareup.com>"
      git_changes.first[:date].should == "Fri Oct 19 17:43:47 2012 -0700"
      git_changes.first[:message].should == "this is my commit message"
    end

    it "should strip new lines in the commit message" do
      GitRepo.stub(:inside_repo).and_return("::!::817b88|User One|Fri Oct 19|this is my commit message\nanother line::!::")
      git_changes = subject
      git_changes.first[:message].should == "this is my commit message another line"
    end
  end

  describe "#changes_in_branch" do
    subject { GitBlame.changes_in_branch(build) }

    before do
      GitBlame.unstub(:changes_in_branch)
    end

    it "should parse the git log message and return a hash of information" do
      GitRepo.stub(:inside_repo).and_return("::!::817b88be7488cab5e4f9d9975222db80d8bceb3b|User One <github+uo@squareup.com>|Fri Oct 19 17:43:47 2012 -0700|this is my commit message::!::")
      git_changes = subject
      git_changes.first[:hash].should == "817b88be7488cab5e4f9d9975222db80d8bceb3b"
      git_changes.first[:author].should == "User One <github+uo@squareup.com>"
      git_changes.first[:date].should == "Fri Oct 19 17:43:47 2012 -0700"
      git_changes.first[:message].should == "this is my commit message"
    end
  end

  describe "#files_changed_since_last_green" do
    subject { GitBlame.files_changed_since_last_green(build) }

    before do
      GitBlame.unstub(:files_changed_since_last_green)
    end

    it "should parse the git log and return change file paths" do
      GitRepo.stub(:inside_repo).and_return("::!::817b88be7488cab5e4f9d9975222db80d8bceb3b::!::\n\npath/one/file.java\npath/two/file.java")
      git_file_changes = subject
      git_file_changes.size.should == 2
      git_file_changes.should include("path/one/file.java")
      git_file_changes.should include("path/two/file.java")
    end
  end

  describe "#files_changed_in_branch" do
    subject { GitBlame.files_changed_in_branch(build) }

    before do
      GitBlame.unstub(:files_changed_in_branch)
    end

    it "should parse the git log and return change file paths" do
      GitRepo.stub(:inside_repo).and_return("::!::817b88be7488cab5e4f9d9975222db80d8bceb3b::!::\n\npath/one/file.java\npath/two/file.java")
      git_file_changes = subject
      git_file_changes.size.should == 2
      git_file_changes.should include("path/one/file.java")
      git_file_changes.should include("path/two/file.java")
    end
  end
end