require 'github_commit_status'
require 'github_post_receive_hook'
require 'github_request'

module RemoteServer

  # All integration with Github must go via this class.
  class Github
    URL_PARSERS = [
      %r{\Agit@(?<host>.*):(?<username>.*)/(?<name>[-.\w]+?)(\.git)?\z},       # git@
      %r{\Agit://(?<host>.*)/(?<username>.*)/(?<name>[-.\w]+)\.git\z},         # git://  (GHE only)
      %r{\Ahttps?://(?<host>.*)/(?<username>.*)/(?<name>[-.\w]+?)(\.git)?\z},  # https://
    ]

    def initialize(url)
      @url = url
      attributes # force url parsing
      @settings = Settings.git_server(@url)
    end

    def attributes
      @attributes ||= begin
        parser = URL_PARSERS.detect { |regexp| @url =~ regexp }
        raise UnknownUrlFormat, "Do not recognize #{@url} as a github URL." unless parser

        match = @url.match(parser)

        {
          host: match[:host],
          repository_namespace: match[:username],
          repository_name: match[:name]
        }.freeze
      end
    end

    # Public: Returns a url for the remote repo in the format Kochiku prefers
    # for Github, which is the SSH format.
    def canonical_repository_url
      "git@#{@settings.host}:#{attributes[:repository_namespace]}/#{attributes[:repository_name]}.git"
    end

    def sha_for_branch(branch)
      response_body = GithubRequest.get(URI("#{base_api_url}/git/refs/heads/#{branch}"))
      branch_info = JSON.parse(response_body)
      sha = nil
      if branch_info['object'] && branch_info['object']['sha'].present?
        sha = branch_info['object']['sha']
      end
      sha
    rescue GithubRequest::ResponseError
      raise RefDoesNotExist
    end

    def update_commit_status!(build)
      GithubCommitStatus.new(build).update_commit_status!
    end

    def install_post_receive_hook!(repo)
      GithubPostReceiveHook.new(repo).subscribe!
    end

    def base_api_url
      if @url =~ /github\.com/
        "https://api.#{attributes[:host]}/repos/#{attributes[:repository_namespace]}/#{attributes[:repository_name]}"
      else # github enterprise
        "https://#{attributes[:host]}/api/v3/repos/#{attributes[:repository_namespace]}/#{attributes[:repository_name]}"
      end
    end

    def href_for_commit(sha)
      "#{base_html_url}/commit/#{sha}"
    end

    def base_html_url
      "https://#{attributes[:host]}/#{attributes[:repository_namespace]}/#{attributes[:repository_name]}"
    end
  end

end
