require 'github_commit_status'
require 'github_post_receive_hook'
require 'github_request'
require 'git_merge_executor'

module RemoteServer
  # All integration with Github must go via this class.
  class Github
    URL_PARSERS = [
      %r{\Agit@(?<host>[^:]*):(?<username>[^\/]*)/(?<name>[-.\w]+?)(\.git)?\z},        # git@
      %r{\Agit://(?<host>[^\/]*)/(?<username>[^\/]*)/(?<name>[-.\w]+)\.git\z},         # git://  (GHE only)
      %r{\Ahttps?://(?<host>[^\/]*)/(?<username>[^\/]*)/(?<name>[-.\w]+?)(\.git)?\z},  # https://
    ].freeze

    def initialize(url, server)
      @url = url
      @settings = server
      attributes # force url parsing
    end

    def attributes
      @attributes ||= begin
        parser = URL_PARSERS.detect { |regexp| @url =~ regexp }
        raise UnknownUrlFormat, "Do not recognize #{@url} as a github URL." unless parser

        match = @url.match(parser)

        {
          host: match[:host],
          repository_namespace: match[:username],
          repository_name: match[:name],
          possible_hosts: [@settings.host, *@settings.aliases].compact,
        }.freeze
      end
    end

    # Class to use for merge methods
    def merge_executor
      GitMergeExecutor
    end

    # Public: Returns a url for the remote repo in the format Kochiku prefers
    # for Github, which is the SSH format.
    def canonical_repository_url
      "git@#{@settings.host}:#{attributes[:repository_namespace]}/#{attributes[:repository_name]}.git"
    end

    def url_for_compare(first_commit_hash, second_commit_hash)
      "#{base_html_url}/compare/#{first_commit_hash}...#{second_commit_hash}#files_bucket"
    end

    # Where to fetch from: git mirror if defined,
    # otherwise the canonical url
    def url_for_fetching
      if @settings.mirror.present?
        canonical_repository_url.gsub(%r{(git@|https://).*?(:|/)}, @settings.mirror)
      else
        canonical_repository_url
      end
    end

    def sha_for_branch(branch)
      response_body = GithubRequest.get("#{base_api_url}/git/refs/heads/#{branch}", @settings.oauth_token)
      branch_info = JSON.parse(response_body)
      sha = nil
      if branch_info['object'] && branch_info['object']['sha'].present?
        sha = branch_info['object']['sha']
      end
      sha
    rescue GithubRequest::ResponseError
      raise RefDoesNotExist, "Could not locate ref #{branch} on remote git server"
    end

    def update_commit_status!(build)
      GithubCommitStatus.new(build, @settings.oauth_token).update_commit_status!
    end

    def install_post_receive_hook!(repo)
      GithubPostReceiveHook.new(repo, @settings.oauth_token).subscribe!
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
