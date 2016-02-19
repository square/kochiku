Kochiku::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  config.cache_classes = true
  config.eager_load = true

  config.consider_all_requests_local = true   # internal service; safe to show errors
  config.action_controller.perform_caching = true

  config.cache_store = :readthis_store, {
    expires_in: 2.days.to_i,
    namespace: 'cache',
    marshal: Readthis::Passthrough,
    redis: {
      host: Settings.redis_host,
      port: Settings.redis_port,
      db: 1, # use different db than Resque
      driver: :hiredis
    }
  }

  # Disable Rails's static asset server (Apache or nginx will already do this)
  config.serve_static_files = false

  # Compress JavaScripts and CSS
  config.assets.js_compressor = :uglifier

  # Don't fallback to assets pipeline if a precompiled asset is missed
  config.assets.compile = false

  # Generate digests for assets URLs
  config.assets.digest = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # See everything in the log (default is :info)
  # config.log_level = :debug

  # Disable delivery errors, bad email addresses will be ignored
  # config.action_mailer.raise_delivery_errors = false

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found)
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners
  config.active_support.deprecation = :notify

  # Disable automatic flushing of the log to improve performance.
  # config.autoflush_log = false

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = ::Logger::Formatter.new

  Rails.application.routes.default_url_options[:host] = Settings.kochiku_host
  Rails.application.routes.default_url_options[:protocol] = Settings.kochiku_protocol
  config.action_mailer.default_url_options = {:host => Settings.kochiku_host, :protocol => Settings.kochiku_protocol}

  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    :address => Settings.smtp_server,
    :port => 25
  }
end
