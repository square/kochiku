require 'cocaine'

class GitBlame
  class << self
    def emails_of_build_breakers(build)
      names_and_emails = fetch_name_email_pairs(build).split("\n")

      emails = names_and_emails.map do |name_and_email|
        name, email = name_and_email.split(":")
        email
      end
    end

    private

    def fetch_name_email_pairs(build)
      GitRepo.inside_repo(build) do
        Cocaine::CommandLine.new("git log", "--format=%an:%ae", "--no-merges", "#{build.previous_successful_build.try(:ref)}...#{build.ref}").run
      end
    end
  end
end