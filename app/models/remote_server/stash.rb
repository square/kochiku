module RemoteServer

  # All integration with Stash must go via this class.
  class Stash
    attr_reader :repo, :stash_request

    def self.project_params(url)
      match = url.match(%r{https://([^@]+)/scm/(.+)/(.+)\.git})

      if match
        {
          host:       match[1],
          username:   match[2],
          repository: match[3],
        }
      else
        raise UnknownUrl, "Do not recognize #{url} as a stash HTTPS url."
      end
    end

    def self.convert_to_ssh_url(params)
      "git@#{params[:host]}:#{params[:port]}/#{params[:username].downcase}/#{params[:repository]}.git"
    end

    def initialize(repo)
      @repo = repo
      @settings = Settings.git_server(repo.url)
      @stash_request = StashRequest.new(@settings)
    end

    def sha_for_branch(branch)
      return branch if branch =~ /\A[0-9a-f]{40}\Z/

      response_body = @stash_request.get(base_api_url + "/branches?filterText=#{branch}")
      response = JSON.parse(response_body)
      sha = nil
      branch_data = response["values"].find {|x| x['displayId'] == branch }
      sha = branch_data['latestChangeset'] if branch_data
      sha
    end

    def update_commit_status!(build)
      build_url = Rails.application.routes.url_helpers.project_build_url(build.project, build)

      # TODO: Tie host to build/repository.
      @stash_request.post "https://#{@settings.host}/rest/build-status/1.0/commits/#{build.ref}", {
        state:       stash_status_for(build),
        key:         'kochiku',
        name:        "kochiku-#{build.id}",
        url:         build_url,
        description: ""
      }
    end

    def install_post_receive_hook!
      # Unimplemented
    end

    def promote_branch!(branch, ref)
      GitRepo.in_repo(repo) do
        BuildStrategy.promote(:branch, branch, ref)
      end
    end

    def base_api_url
      params = repo.project_params

      "https://#{params[:host]}/rest/api/1.0/projects/#{params[:username]}/repos/#{params[:repository]}"
    end

    def base_html_url
      params = repo.project_params

      "https://#{params[:host]}/projects/#{params[:username]}/repos/#{params[:repository]}"
    end

    def href_for_commit(sha)
      "#{base_html_url}/commits/#{sha}"
    end

    private

    def stash_status_for(build)
      if build.succeeded?
        'SUCCESSFUL'
      elsif build.failed? || build.aborted?
        'FAILED'
      else
        'INPROGRESS'
      end
    end
  end

  class StashRequest
    def initialize(settings)
      @settings = settings
    end

    # TODO: Configure OAuth

    def setup_auth!(req)
      req.basic_auth \
        @settings.username,
        File.read(@settings.password_file).chomp
    end

    def get(uri)
      Rails.logger.info("Stash GET: #{uri}")
      get = Net::HTTP::Get.new(uri)
      setup_auth! get
      make_request(get, URI(uri))
    end

    def post(uri, body)
      Rails.logger.info("Stash POST: #{uri}, #{body}")
      post = Net::HTTP::Post.new(uri, {'Content-Type' =>'application/json'})
      setup_auth! post
      post.body = body.to_json
      make_request(post, URI(uri))
    end

    def make_request(method, uri, args = [])
      body = nil
      Net::HTTP.start(uri.host, uri.port, :use_ssl => true) do |http|
        response = http.request(method, *args)
        body = response.body
        Rails.logger.info("Stash response: #{response.inspect}")
        Rails.logger.info("Stash response body: #{body.inspect}")
        unless response.is_a? Net::HTTPSuccess
          raise "response: #{response.class} body: #{body}"
        end
      end
      body
    end
  end

end
