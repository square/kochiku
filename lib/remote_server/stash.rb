require 'cgi'
require 'stash_merge_executor'

module RemoteServer
  class StashAPIError < StandardError; end

  # All integration with Stash must go via this class.
  class Stash
    attr_reader :stash_request

    URL_PARSERS = [
      %r{\Agit@(?<host>[^:]*):(?<username>[^\/]*)/(?<name>[-.\w]+)\.git\z},
      %r{\Assh://git@(?<host>[^\/]*?)(?<port>:\d+)?/(?<username>[^\/]*)/(?<name>[-.\w]+)\.git\z},
      %r{\Ahttps://(?<host>[^@\/]+)/scm/(?<username>[^\/]*)/(?<name>[-.\w]+)\.git\z},
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

    # Class to use for merge methods
    def merge_executor
        StashMergeExecutor
    end

    # Public: Returns a url for the remote repo in the format Kochiku prefers
    # for Stash, which is the HTTPS format.
    def canonical_repository_url
      "https://#{@settings.host}/scm/#{attributes[:repository_namespace]}/#{attributes[:repository_name]}.git"
    end

    # Currently, stash does not support comparison between two arbitrary hashes-- it only supports comparison
    # between heads of branches.
    # For now, we return the comparison of HEAD at refs/heads/master and the branch for the green_builds, if any
    def url_for_compare(first_commit_branch, second_commit_branch)
      if second_commit_branch.blank?
        "#{base_html_url}/compare/commits?targetBranch=refs%2Fheads%2Fmaster"
      else
        "#{base_html_url}/compare/commits?targetBranch=#{second_commit_branch}&sourceBranch=refs%2Fheads%2Fmaster"
      end
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
      build_url = Rails.application.routes.url_helpers.repository_build_url(build.repository.to_param, build)

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

    # uses the stash REST api to merge a pull request
    # raises StashAPIError if an error occurs
    # otherwise returns true or false depending on whether merge succeeds
    #
    # TODO pass in expected SHA for head to branch to prevent merging a branch
    # that is in an unexpected state
    def merge(branch)
      pr_id, pr_version = get_pr_id_and_version(branch)
      success = can_merge?(pr_id) && perform_merge(pr_id, pr_version)

      if success
        Rails.logger.info("Request to stash to merge PR #{pr_id} for branch #{branch} succeeded.")
      else
        Rails.logger.info("Request to stash to merge PR #{pr_id} for branch #{branch} failed.")
      end

      success
    end

    # uses the stash REST api to delete a branch
    # raises StashAPIError if error occurs, else return true
    def delete_branch(branch, dryRun = false)
      url = "https://#{attributes[:host]}/rest/branch-utils/1.0/projects/#{attributes[:repository_namespace]}/repos/#{attributes[:repository_name]}/branches"

      delete_params = {
        "name" => branch,
        "dryRun" => dryRun
      }

      response = @stash_request.delete(url, delete_params)

      if response
        jsonbody = JSON.parse(response)
        raise StashAPIError, jsonbody["errors"].to_s if jsonbody["errors"]
      end

      true
    end

    # return PR id, version number if a single PR exists for corresponding branch
    # else raise StashAPIError
    def get_pr_id_and_version(branch)
      url = "#{base_api_url}/pull-requests?direction=outgoing&at=refs/heads/#{branch}&state=open&limit=25"
      response = @stash_request.get(url)
      jsonbody = JSON.parse(response)
      raise StashAPIError if jsonbody["errors"].present? || jsonbody["size"] != 1

      return jsonbody["values"][0]["id"], jsonbody["values"][0]["version"]
    end

    private

    # use stash REST api to query if a merge is possible
    # raise StashAPIError if an error in API response, else return true
    def can_merge?(pr_id)
      url = "#{base_api_url}/pull-requests/#{pr_id}/merge"
      response = @stash_request.get(url)

      jsonbody = JSON.parse(response)

      raise StashAPIError if jsonbody["errors"]

      if jsonbody["canMerge"] == false
        Rails.logger.info("Could not merge PR #{pr_id}:")
        Rails.logger.info("conflicted: #{jsonbody["conflicted"]}")
        Rails.logger.info("vetoes: #{jsonbody["vetoes"]}")
        return false
      end

      true
    end

    # use stash REST api to merge PR
    # raise StashAPIError if an error in API response, else return true
    def perform_merge(pr_id, pr_version)
      url = "#{base_api_url}/pull-requests/#{pr_id}/merge?version=#{pr_version}"
      response = @stash_request.post(url, nil)
      jsonbody = JSON.parse(response)

      raise StashAPIError if jsonbody["errors"]
      true
    end

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
        req.basic_auth(@settings.stash_username, @settings.stash_password)
      end

      def get(url)
        Rails.logger.info("Stash GET: #{url}")
        get = Net::HTTP::Get.new(url)
        setup_auth! get
        make_request(get, URI(url))
      end

      def post(url, body={})
        Rails.logger.info("Stash POST: #{url}, #{body}")
        post = Net::HTTP::Post.new(url, {'Content-Type' =>'application/json'})
        setup_auth! post
        post.body = body.to_json
        make_request(post, URI(url))
      end

      def delete(url, body)
        Rails.logger.info("Stash DELETE: #{url}, #{body}")
        delete_request = Net::HTTP::Delete.new(url, {'Content-Type' =>'application/json'})
        setup_auth! delete_request
        body ||= {}
        delete_request.body = body.to_json
        make_request(delete_request, URI(url))
      end

      def make_request(method, url, args = [])
        uri = URI(url)
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
