require 'cocaine'

class GitBlame
  PEOPLE_JSON_URL = 'https://people.squareup.com/people.json'

  class << self
    def emails_of_build_breakers(build)
      names_and_emails_from_git = ungreen_name_emails_from_git(build).split("\n")
      names_and_emails_from_git.map do |name_and_email_from_git|
        name, email = name_and_email_from_git.split(":")
        Array(email_from_git_email(email)) | Array(email_from_git_name(name))
      end.flatten.compact.uniq
    end

    private

    def email_from_git_email(email)
      if people_lookup[:by_email][email].present?
        email
      else
        usernames = email.split('@').first.split('+')
        usernames.map do |username|
          username.strip!
          people_lookup[:by_username][username].try(:[], :email)
        end
      end
    end

    def email_from_git_name(name)
      if people_lookup[:by_name][name].present?
        people_lookup[:by_name][name][:email]
      else
        names = (name.split(/ and /i) | name.split('+') | name.split(',') | name.split('&')) - [name]
        names.map do |_name|
          _name.strip!
          people_lookup[:by_name][_name].try(:[], :email)
        end
      end
    end

    def people_lookup
      return @people_lookup if @people_lookup

      @people_lookup = {:by_email => {}, :by_name => {}, :by_username => {}}
      people_from_ldap.each { |person|
        @people_lookup[:by_email][person['Email']] = {:name => "#{person['First']} #{person['Last']}"}
        @people_lookup[:by_name]["#{person['First']} #{person['Last']}"] = {:email => "#{person['Email']}"}
        @people_lookup[:by_username]["#{person['Username']}"] = {:email => "#{person['Email']}"}
      }
      @people_lookup
    end

    def people_from_ldap
      @people_from_ldap ||= JSON.parse(HTTParty.get(PEOPLE_JSON_URL))
    end

    def ungreen_name_emails_from_git(build)
      GitRepo.inside_repo(build.repository) do
        Cocaine::CommandLine.new("git log --format=%an:%ae --no-merges #{build.previous_successful_build.try(:ref)}...#{build.ref}").run
      end
    end
  end
end