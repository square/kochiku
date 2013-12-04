require 'spec_helper'

describe GitBlame do
  let(:repository) { FactoryGirl.create(:repository, url: 'git@github.com:square/test-repo.git') }
  let(:project) { FactoryGirl.create(:big_rails_project, repository: repository) }
  let(:build) { FactoryGirl.create(:build, :project => project) }

  describe "#emails_since_last_green" do
    subject { GitBlame.emails_since_last_green(build) }

    context "with many build breakers, and no git prefix" do
      before do
        GitBlame.stub(:git_names_and_emails_since_last_green).and_return("User One:userone@example.com\nUser Two:usertwo@example.com")
      end

      it "returns the emails of the users" do
        subject.should == ["userone@example.com", "usertwo@example.com"]
      end

      it "will not return the same user twice" do
        GitBlame.stub(:git_names_and_emails_since_last_green).and_return("User One:userone@example.com\nUser One:userone@example.com")
        subject.should == ["userone@example.com"]
      end
    end

    context "with a git prefix" do
      before do
        allow(Settings).to receive(:git_pair_email_prefix).and_return("git")
      end

      it "should be able to extract a single user" do
        GitBlame.stub(:git_names_and_emails_since_last_green).and_return("First Last:git+userone@example.com")
        subject.should == ["userone@example.com"]
      end

      it "should be able to extract multiple users" do
        GitBlame.stub(:git_names_and_emails_since_last_green).and_return("First Last:git+one+two+three@example.com")
        subject.should == ["one@example.com", "two@example.com", "three@example.com"]
      end

      it "does not affect users with no plus sign" do
        GitBlame.stub(:git_names_and_emails_since_last_green).and_return("One:one@example.com\nTwo:two@foo.example.org")
        subject.should == ["one@example.com", "two@foo.example.org"]
      end

      it "does not affect an email with a similar format but not starting with the prefix and a plus sign" do
        GitBlame.stub(:git_names_and_emails_since_last_green).and_return("One:github+one+two@example.com")
        subject.should == ["github+one+two@example.com"]
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
    let(:options) { {} }
    subject { GitBlame.files_changed_since_last_green(build, options) }

    before do
      GitBlame.unstub(:files_changed_since_last_green)
    end

    it "should parse the git log and return change file paths" do
      GitRepo.stub(:inside_repo).and_return("::!::User One:userone@example.com::!::\n\npath/one/file.java\npath/two/file.java")
      git_file_changes = subject
      git_file_changes.size.should == 2
      git_file_changes.should include({:file => "path/one/file.java", :emails => []})
      git_file_changes.should include({:file => "path/two/file.java", :emails => []})
    end

    context "fetch emails with files changes" do
      let(:options) { {:fetch_emails => true} }

      it "should parse the git log and return change file paths with emails" do
        GitRepo.stub(:inside_repo).and_return("::!::User One:userone@example.com::!::\n\npath/one/file.java\npath/two/file.java\n::!::User Two:usertwo@example.com::!::\n\npath/three/file.java")
        git_file_changes = subject
        git_file_changes.size.should == 3
        git_file_changes.should include({:file => "path/one/file.java", :emails => ["userone@example.com"]})
        git_file_changes.should include({:file => "path/two/file.java", :emails => ["userone@example.com"]})
        git_file_changes.should include({:file => "path/three/file.java", :emails => ["usertwo@example.com"]})
      end

      it "should return nothing if the line doesn't have an email" do
        GitRepo.stub(:inside_repo).and_return("::!::::!::\n")
        subject.should be_empty
      end
    end
  end

  describe "#files_changed_in_branch" do
    let(:options) { {} }
    subject { GitBlame.files_changed_in_branch(build, options) }

    before do
      GitBlame.unstub(:files_changed_in_branch)
    end

    it "should parse the git log and return change file paths" do
      GitRepo.stub(:inside_repo).and_return("::!::User One:userone@example.com::!::\n\npath/one/file.java\npath/two/file.java")
      git_file_changes = subject
      git_file_changes.size.should == 2
      git_file_changes.should include({:file => "path/one/file.java", :emails => []})
      git_file_changes.should include({:file => "path/two/file.java", :emails => []})
    end
  end
end
