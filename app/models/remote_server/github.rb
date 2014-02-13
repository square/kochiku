require 'github_commit_status'
require 'github_post_receive_hook'
require 'github_request'

module RemoteServer

  # All integration with Github must go via this class.
  class Github
    attr_reader :repo

    URL_PARSERS = [
      %r{@(?<host>.*):(?<username>.*)/(?<project_name>.*)\.git},           # git@
      %r{://(?<host>.*)/(?<username>.*)/(?<project_name>.*)\.git},         # git://
      %r{https?://(?<host>.*)/(?<username>.*)/(?<project_name>[^.]*)\.?},  # https://
    ]

    def self.convert_to_ssh_url(url)
      params = project_params(url)
      "git@#{params[:host]}:#{params[:username]}/#{params[:repository]}.git"
    end

    def self.project_params(url)
      parser = URL_PARSERS.detect { |regexp| url =~ regexp }
      raise UnknownUrl, "Do not recognize #{url} as a github URL." unless parser

      match = url.match(parser)

      {
        host:       match[:host],
        username:   match[:username],
        repository: match[:project_name]
      }
    end

    def initialize(repo)
      @repo = repo
    end

    def sha_for_branch(branch)
      response_body = GithubRequest.get(URI("#{base_api_url}/git/refs/heads/#{branch}"))
      branch_info = JSON.parse(response_body)
      sha = nil
      if branch_info['object'] && branch_info['object']['sha'].present?
        sha = branch_info['object']['sha']
      end
      sha
    end

    def update_commit_status!(build)
      GithubCommitStatus.new(build).update_commit_status!
    end

    def install_post_receive_hook!
      GithubPostReceiveHook.new(repo).subscribe!
    end

    def promote_branch!(branch, ref)
      Rails.logger.info("Github#promote_branch: #{branch}, #{ref}")
      begin
        GithubRequest.post(
          URI("#{base_api_url}/git/refs"),
          :ref => "refs/heads/#{branch}",
          :sha => ref
        )
      rescue GithubRequest::ResponseError
         # We expect a 422 when the branch exists
        Rails.logger.info("Failed to create git ref for #{branch}")
      end

      GithubRequest.patch(
        URI("#{base_api_url}/git/refs/heads/#{branch}"),
        :sha => ref,
        :force => "true"
      )
    end

    def base_api_url
      params = repo.project_params

      if repo.url =~ /github\.com/
        "https://api.#{params[:host]}/repos/#{params[:username]}/#{params[:repository]}"
      else # github enterprise
        "https://#{params[:host]}/api/v3/repos/#{params[:username]}/#{params[:repository]}"
      end
    end

    def href_for_commit(sha)
      "#{base_html_url}/commit/#{sha}"
    end

    def base_html_url
      params = repo.project_params

      "https://#{params[:host]}/#{params[:username]}/#{params[:repository]}"
    end
  end

end
