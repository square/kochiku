require 'spec_helper'

describe GitBlame do
  let(:repository) { FactoryGirl.create(:repository, url: 'git@github.com:square/test-repo.git') }
  let(:project) { FactoryGirl.create(:big_rails_project, repository: repository) }
  let(:build) { FactoryGirl.create(:build, :project => project) }

  describe "#emails_since_last_green" do
    subject { GitBlame.emails_since_last_green(build) }

    context "with many build breakers, and no git prefix" do
      before do
        allow(GitBlame).to receive(:git_names_and_emails_since_last_green).and_return(["User One:userone@example.com","User Two:usertwo@example.com"])
      end

      it "returns the emails of the users" do
        expect(subject).to eq(["userone@example.com", "usertwo@example.com"])
      end

      it "will not return the same user twice" do
        allow(GitBlame).to receive(:git_names_and_emails_since_last_green).and_return(["User One:userone@example.com","User One:userone@example.com"])
        expect(subject).to eq(["userone@example.com"])
      end
    end

    context "with a git prefix" do
      before do
        allow(Settings).to receive(:git_pair_email_prefix).and_return("git")
      end

      it "should be able to extract a single user" do
        allow(GitBlame).to receive(:git_names_and_emails_since_last_green).and_return(["First Last:git+userone@example.com"])
        expect(subject).to eq(["userone@example.com"])
      end

      it "should be able to extract multiple users" do
        allow(GitBlame).to receive(:git_names_and_emails_since_last_green).and_return(["First Last:git+one+two+three@example.com"])
        expect(subject).to eq(["one@example.com", "two@example.com", "three@example.com"])
      end

      it "does not affect users with no plus sign" do
        allow(GitBlame).to receive(:git_names_and_emails_since_last_green).and_return(["One:one@example.com","Two:two@foo.example.org"])
        expect(subject).to eq(["one@example.com", "two@foo.example.org"])
      end

      it "does not affect an email with a similar format but not starting with the prefix and a plus sign" do
        allow(GitBlame).to receive(:git_names_and_emails_since_last_green).and_return(["One:github+one+two@example.com"])
        expect(subject).to eq(["github+one+two@example.com"])
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
        allow(GitBlame).to receive(:git_names_and_emails_in_branch).and_return(["User One:userone@example.com","User Two:usertwo@example.com"])
      end

      it "returns the emails of the users" do
        expect(subject).to eq(["userone@example.com", "usertwo@example.com"])
      end
    end
  end

  describe "#last_email_in_branch" do
    subject { GitBlame.last_email_in_branch(build) }

    before do
      allow(GitBlame).to receive(:last_git_name_and_email_in_branch).and_return("User One:userone@example.com")
    end

    it "returns a single email" do
        expect(subject).to eq(["userone@example.com"])
    end
  end

  describe "#changes_since_last_green" do
    subject { GitBlame.changes_since_last_green(build) }

    before do
      allow(GitBlame).to receive(:changes_since_last_green).and_call_original
    end

    it "should parse the git log message and return a hash of information" do
      allow(GitRepo).to receive(:inside_repo).and_return("::!::817b88be7488cab5e4f9d9975222db80d8bceb3b|User One <github+uo@squareup.com>|Fri Oct 19 17:43:47 2012 -0700|this is my commit message::!::")
      git_changes = subject
      expect(git_changes.first[:hash]).to eq("817b88be7488cab5e4f9d9975222db80d8bceb3b")
      expect(git_changes.first[:author]).to eq("User One <github+uo@squareup.com>")
      expect(git_changes.first[:date]).to eq("Fri Oct 19 17:43:47 2012 -0700")
      expect(git_changes.first[:message]).to eq("this is my commit message")
    end

    it "should strip new lines in the commit message" do
      allow(GitRepo).to receive(:inside_repo).and_return("::!::817b88|User One|Fri Oct 19|this is my commit message\nanother line::!::")
      git_changes = subject
      expect(git_changes.first[:message]).to eq("this is my commit message another line")
    end
  end

  describe "#changes_in_branch" do
    subject { GitBlame.changes_in_branch(build) }

    before do
      allow(GitBlame).to receive(:changes_in_branch).and_call_original
    end

    it "should parse the git log message and return a hash of information" do
      allow(GitRepo).to receive(:inside_repo).and_return("::!::817b88be7488cab5e4f9d9975222db80d8bceb3b|User One <github+uo@squareup.com>|Fri Oct 19 17:43:47 2012 -0700|this is my commit message::!::")
      git_changes = subject
      expect(git_changes.first[:hash]).to eq("817b88be7488cab5e4f9d9975222db80d8bceb3b")
      expect(git_changes.first[:author]).to eq("User One <github+uo@squareup.com>")
      expect(git_changes.first[:date]).to eq("Fri Oct 19 17:43:47 2012 -0700")
      expect(git_changes.first[:message]).to eq("this is my commit message")
    end
  end

  describe "#files_changed_since_last_green" do
    let(:options) { {} }
    subject { GitBlame.files_changed_since_last_green(build, options) }

    before do
      allow(GitBlame).to receive(:files_changed_since_last_green).and_call_original
    end

    it "should parse the git log and return change file paths" do
      allow(GitRepo).to receive(:inside_repo).and_return("::!::User One:userone@example.com::!::\n\npath/one/file.java\npath/two/file.java")
      git_file_changes = subject
      expect(git_file_changes.size).to eq(2)
      expect(git_file_changes).to include({:file => "path/one/file.java", :emails => []})
      expect(git_file_changes).to include({:file => "path/two/file.java", :emails => []})
    end

    context "fetch emails with files changes" do
      let(:options) { {:fetch_emails => true} }

      it "should parse the git log and return change file paths with emails" do
        allow(GitRepo).to receive(:inside_repo).and_return("::!::User One:userone@example.com::!::\n\npath/one/file.java\npath/two/file.java\n::!::User Two:usertwo@example.com::!::\n\npath/three/file.java")
        git_file_changes = subject
        expect(git_file_changes.size).to eq(3)
        expect(git_file_changes).to include({:file => "path/one/file.java", :emails => ["userone@example.com"]})
        expect(git_file_changes).to include({:file => "path/two/file.java", :emails => ["userone@example.com"]})
        expect(git_file_changes).to include({:file => "path/three/file.java", :emails => ["usertwo@example.com"]})
      end

      it "should return nothing if the line doesn't have an email" do
        allow(GitRepo).to receive(:inside_repo).and_return("::!::::!::\n")
        expect(subject).to be_empty
      end
    end
  end

  describe "#files_changed_in_branch" do
    let(:options) { {} }
    subject { GitBlame.files_changed_in_branch(build, options) }

    before do
      allow(GitBlame).to receive(:files_changed_in_branch).and_call_original
    end

    it "should parse the git log and return change file paths" do
      allow(GitRepo).to receive(:inside_repo).and_return("::!::User One:userone@example.com::!::\n\npath/one/file.java\npath/two/file.java")
      git_file_changes = subject
      expect(git_file_changes.size).to eq(2)
      expect(git_file_changes).to include({:file => "path/one/file.java", :emails => []})
      expect(git_file_changes).to include({:file => "path/two/file.java", :emails => []})
    end
  end
end
