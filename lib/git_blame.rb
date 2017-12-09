require 'cocaine'
require 'git_repo'

class GitBlame
  class << self
    def emails_since_last_green(build)
      lookup_git_names_and_emails(git_names_and_emails_since_last_green(build))
    end

    def emails_in_branch(build)
      lookup_git_names_and_emails(git_names_and_emails_in_branch(build))
    end

    def last_email_in_branch(build)
      lookup_git_names_and_emails(last_git_name_and_email_in_branch(build))
    end

    def changes_since_last_green(build)
      output = GitRepo.inside_repo(build.repository) do
        # TODO: Push this down into GitRepo and integration test it.
        Cocaine::CommandLine.new("git log --cc --format='::!::%H|%cn <%ce>|%cd|%B::!::' '#{build.previous_successful_build.try(:ref)}...#{build.ref}'").run
      end
      parse_git_changes(output)
    end

    def changes_in_branch(build)
      output = GitRepo.inside_repo(build.repository) do
        # TODO: Push this down into GitRepo and integration test it.
        Cocaine::CommandLine.new("git log --cc --format='::!::%H|%cn <%ce>|%cd|%B::!::' 'master..#{build.branch_record.name}'").run
      end
      parse_git_changes(output)
    end

    def files_changed_since_last_build(build, fetch_emails: false, sync: true)
      output = GitRepo.inside_repo(build.repository, sync: sync) do
        Cocaine::CommandLine.new("git log --cc --format='::!::%an:%ae::!::' --name-only '#{build.previous_build.try(:ref)}...#{build.ref}'").run
      end
      parse_git_files_changes(output, fetch_emails: fetch_emails)
    end

    def files_changed_since_last_green(build, fetch_emails: false)
      output = GitRepo.inside_repo(build.repository) do
        # TODO: Push this down into GitRepo and integration test it.
        Cocaine::CommandLine.new("git log --cc --format='::!::%cn:%ce::!::' --name-only '#{build.previous_successful_build.try(:ref)}...#{build.ref}'").run
      end
      parse_git_files_changes(output, fetch_emails: fetch_emails)
    end

    def files_changed_in_branch(build, fetch_emails: false, sync: true)
      output = GitRepo.inside_repo(build.repository, sync: sync) do
        # TODO: Push this down into GitRepo and integration test it.
        Cocaine::CommandLine.new("git log --cc --format='::!::%cn:%ce::!::' --name-only 'master..#{build.branch_record.name}'").run
      end
      parse_git_files_changes(output, fetch_emails: fetch_emails)
    end

    # net_files_changed_in_branch counts only files which have a net diff in the branch. If a branch includes a commit
    # to modify a file, and then a revert commit, that file will not be included in this list.
    def net_files_changed_in_branch(build, sync: true)
      # get revision of shared ancestor of master and build branch, i.e. the commit at which point this branch was created
      common_ancestor = GitRepo.inside_repo(build.repository, sync: sync) do
        Cocaine::CommandLine.new("git merge-base master #{build.branch_record.name}").run
      end

      output = GitRepo.inside_repo(build.repository, sync: sync) do
        Cocaine::CommandLine.new("git diff --name-status --find-renames --find-copies '#{common_ancestor.strip}..#{build.branch_record.name}'").run
      end
      parse_git_changes_by_name_status(output)
    end

    private

    def email_from_git_email(email)
      if email =~ /^#{Settings.git_pair_email_prefix}\+/
        localpart, domain = email.split('@')
        usernames = localpart.strip.split('+')
        usernames[1..-1].map { |username| "#{username}@#{domain}" }
      else
        email
      end
    end

    def git_names_and_emails_since_last_green(build)
      GitRepo.inside_repo(build.repository) do
        Cocaine::CommandLine.new("git log --format='%cn:%ce' '#{build.previous_successful_build.try(:ref)}...#{build.ref}'").run.split("\n")
      end
    end

    def git_names_and_emails_in_branch(build)
      GitRepo.inside_repo(build.repository) do
        if GitRepo.branch_exist?(build.branch_record.name)
          Cocaine::CommandLine.new("git log --format='%cn:%ce' 'master..#{build.branch_record.name}'").run.split("\n")
        else
          []
        end
      end
    end

    def last_git_name_and_email_in_branch(build)
      GitRepo.inside_repo(build.repository) do
        Cocaine::CommandLine.new("git log --format='%cn:%ce' -1 '#{build.branch_record.name}'").run.strip
      end
    end

    def lookup_git_names_and_emails(git_names_and_emails)
      Array(git_names_and_emails).map do |git_name_and_email|
        _name, email = git_name_and_email.split(":")
        Array(email_from_git_email(email))
      end.flatten.compact.uniq
    end

    def parse_git_changes(output)
      output.split("::!::").each_with_object([]) do |line, git_changes|
        commit_hash, author, commit_date, commit_message = line.chomp.split("|")
        next if commit_hash.nil? || commit_message.nil?
        git_changes << {:hash => commit_hash, :author => author, :date => commit_date, :message => commit_message.tr("\n", " ")}
      end
    end

    def parse_git_files_changes(output, fetch_emails: false)
      email_addresses = []
      output.split("\n").each_with_object([]) do |line, file_changes|
        next if line.empty?
        if line.start_with?("::!::")
          email_addresses = []
          if fetch_emails
            line.split("::!::").each do |line_part|
              next if line_part.nil? || line_part.empty?
              _name, email = line_part.split(":")
              email_addresses = email_addresses + Array(email_from_git_email(email))
            end
            email_addresses.compact!
          end
        else
          file_changes << {:file => line, :emails => email_addresses}
        end
      end
    end

    def parse_git_changes_by_name_status(output)
      output.split("\n").each_with_object([]) do |line, file_changes|
        next if line.empty?

        # Format from --name-status prints a status code, then any file names after that.
        # For example, a file rename that has 85% similarity would be output as:
        #   R085   path/to/original_name.java   path/to/new_name.java
        # We can safely reject the first element (status code) in the split array.
        files_in_line = line.split[1..-1]

        files_in_line.each { |file| file_changes << {file: file, emails: []} }
      end
    end
  end
end
