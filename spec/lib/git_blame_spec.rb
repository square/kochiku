require 'spec_helper'

describe GitBlame do
  let(:build) { FactoryGirl.create(:build) }

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

    context "with deleted branch" do
      before do
        allow(GitBlame).to receive(:git_names_and_emails_in_branch).and_call_original
        allow(GitRepo).to receive(:inside_repo).and_yield
        allow(GitRepo).to receive(:branch_exist?).and_return(false)
      end

      it "should should return []" do
        expect(subject).to eq([])
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

  describe "#files_changed_since_last_build" do
    let(:options) { {} }
    subject { GitBlame.files_changed_since_last_build(build, options) }

    before do
      allow(GitBlame).to receive(:files_changed_since_last_build).and_call_original
    end

    it "should parse the git log and return change file paths" do
      allow(GitRepo).to receive(:inside_repo).and_return("::!::User One:userone@example.com::!::\n\npath/one/file.java\npath/two/file.java")
      git_file_changes = subject
      expect(git_file_changes.size).to eq(2)
      expect(git_file_changes).to include({:file => "path/one/file.java", :emails => []})
      expect(git_file_changes).to include({:file => "path/two/file.java", :emails => []})
    end

    context "includes merge commit modifying files that aren't changed in parent commits" do
      # [hack] the git-sha's are not stable on test runs, so we need to use git tags to mark commits
      let(:previous_build) { instance_double('Build', :ref => "a") }
      before do
        build.update(:ref => "d")
        allow(build).to receive(:previous_build).and_return previous_build
        allow(GitRepo).to receive(:inside_repo) do |build, sync_repo, &block|
          Dir.mktmpdir do |directory|
            Dir.chdir(directory) do
              suppressed_git_init
              `git config user.email "test@example.com" && git config user.name "test"`
              FileUtils.touch("TESTFILE")
              `git add -A && git commit -m "commit 1" && git tag a`
              `git checkout -q -b branch`
              FileUtils.touch("TESTFILE2")
              `git add -A && git commit -m "commit 2" && git tag b`
              `git checkout -q -`
              FileUtils.touch("TESTFILE3")
              `git add -A && git commit -m "commit 3" && git tag c`
              # --no-commit allows us to change arbitrary files, like in merge conflict resolution
              `git merge branch --no-ff --no-commit 2> /dev/null`
              # modify a new file during the merge not modified by parents
              FileUtils.touch("NEWFILE")
              `git add -A && git commit -m "merge commit" && git tag d`
              block.call
            end
          end
        end
      end

      it "should include all files modified in merge commit" do
        git_file_changes = subject
        expect(git_file_changes).to_not include({:file=>"TESTFILE", :emails=>[]})
        expect(git_file_changes).to include({:file=>"TESTFILE2", :emails=>[]})
        expect(git_file_changes).to include({:file=>"TESTFILE3", :emails=>[]})
        expect(git_file_changes).to include({:file=>"NEWFILE", :emails=>[]})
      end
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

  describe "#net_files_changed_in_branch" do
    let(:options) { {} }

    let(:git_merge_base_command) { "git merge-base master #{build.branch_record.name}" }
    let(:git_merge_base_output) { '12345' }

    let(:git_diff_command) { "git diff --name-status --find-renames --find-copies '12345..#{build.branch_record.name}'" }
    let(:git_diff_output) {
      <<-GITDIFF
D       path/to/deleted_file.java
M       path/to/modified_file.java
A       path/to/added_file.java
R097    path/to/original_name.java path/to/new_name.java
    GITDIFF
    }

    subject { GitBlame.net_files_changed_in_branch(build, options) }

    before do
      allow(GitBlame).to receive(:net_files_changed_in_branch).and_call_original

      allow(GitRepo).to receive(:inside_repo).and_yield

      diff_double = double('git diff')
      allow(diff_double).to receive(:run).and_return(git_diff_output)
      allow(Cocaine::CommandLine).to receive(:new).with(git_diff_command) { diff_double }

      merge_base_double = double('git merge-base')
      allow(merge_base_double).to receive(:run).and_return(git_merge_base_output)
      allow(Cocaine::CommandLine).to receive(:new).with(git_merge_base_command) { merge_base_double }
    end

    it "should parse the git diff and return change file paths" do
      git_file_changes = subject
      expect(git_file_changes.size).to eq(5)
      expect(git_file_changes).to include({:file => "path/to/added_file.java", :emails => []})
      expect(git_file_changes).to include({:file => "path/to/deleted_file.java", :emails => []})
      expect(git_file_changes).to include({:file => "path/to/modified_file.java", :emails => []})
      expect(git_file_changes).to include({:file => "path/to/original_name.java", :emails => []})
      expect(git_file_changes).to include({:file => "path/to/new_name.java", :emails => []})
    end
  end
end
