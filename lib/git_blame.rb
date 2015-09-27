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
        Cocaine::CommandLine.new("git log --cc --format='::!::%H|%cn <%ce>|%cd|%B::!::' 'origin/master..origin/#{build.branch_record.name}'").run
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
        Cocaine::CommandLine.new("git log --cc --format='::!::%cn:%ce::!::' --name-only 'origin/master..origin/#{build.branch_record.name}'").run
      end
      parse_git_files_changes(output, fetch_emails: fetch_emails)
    end

    private

    def email_from_git_email(email)
      if email =~ /^#{Settings.git_pair_email_prefix}\+/
        localpart, domain = email.split('@')
        usernames = localpart.strip.split('+')
        usernames[1..-1].map { |username| "#{username}@#{domain}"}
      else
        email
      end
    end

    def git_names_and_emails_since_last_green(build)
      GitRepo.inside_repo(build.repository) do
        Cocaine::CommandLine.new("git log --format='%cn:%ce' --cc '#{build.previous_successful_build.try(:ref)}...#{build.ref}'").run.split("\n")
      end
    end

    def git_names_and_emails_in_branch(build)
      GitRepo.inside_repo(build.repository) do
        Cocaine::CommandLine.new("git log --format='%cn:%ce' --cc 'origin/master..origin/#{build.branch_record.name}'").run.split("\n")
      end
    end

    def last_git_name_and_email_in_branch(build)
      GitRepo.inside_repo(build.repository) do
        Cocaine::CommandLine.new("git log --format='%cn:%ce' -1 'origin/#{build.branch_record.name}'").run.strip
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
        next if commit_hash.nil?
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
  end
end
