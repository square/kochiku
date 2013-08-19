module RemoteServer

  # All integration with Github must go via this class.
  class Github
    attr_reader :repo

    def self.match?(url)
      url.include?('git.squareup.com') || url.include?('github.com')
    end

    def self.convert_to_ssh_url(params)
      "git@#{params[:host]}:#{params[:username]}/#{params[:repository]}.git"
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

    def base_api_url
      params = repo.project_params

      "https://#{params[:host]}/api/v3/repos/#{params[:username]}/#{params[:repository]}"
    end

    def base_html_url
      params = repo.project_params

      "https://#{params[:host]}/#{params[:username]}/#{params[:repository]}"
    end
  end

end
