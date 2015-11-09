require 'yaml'
require 'active_support/core_ext/hash/indifferent_access'
require 'server_settings'

class SettingsAccessor
  def initialize(yaml)
    @hash = YAML.load(yaml).with_indifferent_access
  end

  def sender_email_address
    @hash[:sender_email_address]
  end

  def kochiku_notifications_email_address
    @hash[:kochiku_notifications_email_address]
  end

  def domain_name
    @hash[:domain_name]
  end

  def kochiku_protocol
    @hash[:use_https] ? "https" : "http"
  end

  def kochiku_host
    @hash[:kochiku_host]
  end

  def kochiku_host_with_protocol
    "#{kochiku_protocol}://#{kochiku_host}"
  end

  def git_servers
    @git_servers ||= begin
      raw_servers = @hash[:git_servers]
      if raw_servers
        raw_servers.each_with_object({}) do |(host, settings_for_server), result|
          result[host] = ServerSettings.new(settings_for_server, host)
        end
      else
        {}
      end
    end
  end

  def git_server(url)
    git_servers.values.detect do |server|
      url.include?(server.host) ||
        (server.aliases && server.aliases.detect { |a| url.include?(a) })
    end
  end

  def smtp_server
    @hash[:smtp_server]
  end

  def redis_host
    @hash[:redis_host]
  end

  def redis_port
    @hash.fetch(:redis_port, 6379)
  end

  def git_pair_email_prefix
    @hash[:git_pair_email_prefix]
  end

  def worker_thresholds
    @hash[:worker_thresholds]
  end
end
