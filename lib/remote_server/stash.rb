require 'cgi'

module RemoteServer

  # All integration with Stash must go via this class.
  class Stash
    attr_reader :stash_request

    URL_PARSERS = [
      %r{\Agit@(?<host>.*):(?<username>.*)/(?<name>[-.\w]+)\.git\z},
      %r{\Assh://git@(?<host>.*?)(?<port>:\d+)?/(?<username>.*)/(?<name>[-.\w]+)\.git\z},
      %r{\Ahttps://(?<host>[^@]+)/scm/(?<username>.+)/(?<name>[-.\w]+)\.git\z},
    ]

    def initialize(url, server)
      @url = url
      @settings = server
      attributes # force url parsing
      @stash_request = StashRequest.new(@settings)
    end

    def attributes
      @attributes ||= begin
        parser = URL_PARSERS.detect { |regexp| @url =~ regexp }
        raise UnknownUrlFormat, "Do not recognize #{@url} as a Stash url." unless parser

        match = @url.match(parser)

        attributes = {
          host: match[:host],
          repository_namespace: match[:username],
          repository_name: match[:name],
          possible_hosts: [@settings.host, *@settings.aliases].compact,
        }
        if match.names.include?('port') && match['port'].present?
          attributes[:port] = match[:port].delete(':')
        end
        attributes.freeze
      end
    end

    # Public: Returns a url for the remote repo in the format Kochiku prefers
    # for Stash, which is the HTTPS format.
    def canonical_repository_url
      "https://#{@settings.host}/scm/#{attributes[:repository_namespace]}/#{attributes[:repository_name]}.git"
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
      return branch if branch =~ /\A[0-9a-f]{40}\Z/

      response_body = @stash_request.get(base_api_url +
        "/commits?until=#{CGI.escape(branch)}&limit=1")
      response = JSON.parse(response_body)
      branch_data = response["values"][0] || {}
      branch_data['id']
    rescue => e
      case e.message.split(" ")[0]
      when "Net::HTTPNotFound", "Net::HTTPBadRequest"
        raise RefDoesNotExist, "Could not locate ref #{branch} on remote git server"
      else
        raise e
      end
    end

    def update_commit_status!(build)
      build_url = Rails.application.routes.url_helpers.project_build_url(build.project, build)

      @stash_request.post "https://#{@settings.host}/rest/build-status/1.0/commits/#{build.ref}", {
        state:       stash_status_for(build),
        key:         'kochiku',
        name:        "kochiku-#{build.id}",
        url:         build_url,
        description: ""
      }
    end

    def install_post_receive_hook!(repo)
      # Unimplemented
    end

    def base_api_url
      "https://#{attributes[:host]}/rest/api/1.0/projects/#{attributes[:repository_namespace]}/repos/#{attributes[:repository_name]}"
    end

    def base_html_url
      "https://#{attributes[:host]}/projects/#{attributes[:repository_namespace]}/repos/#{attributes[:repository_name]}"
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
            raise "#{response.class} body: #{body}"
          end
        end
        body
      end
    end

  end
end
