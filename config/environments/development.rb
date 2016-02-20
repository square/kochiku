Kochiku::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # In the development environment your application's code is reloaded on
  # every request.  This slows down response time but is perfect for development
  # since you don't have to restart the webserver when you make code changes.
  config.cache_classes = false

  config.eager_load = false

  # Show full error reports
  config.consider_all_requests_local = true

  # Enable page, action, and fragment caching
  #
  # Important to have enabled in development to keep cache related bugs from
  # slipping through.
  config.action_controller.perform_caching = true
  config.cache_store = :memory_store, { size: 67108864 } # 64.megabytes

  # Uncomment to use Redis caching in development
  #
  # config.cache_store = :readthis_store, {
  #   expires_in: 2.days.to_i,
  #   namespace: 'cache',
  #   marshal: Readthis::Passthrough,
  #   redis: {
  #     host: Settings.redis_host,
  #     port: Settings.redis_port,
  #     db: 1, # use different db than Resque
  #     driver: :hiredis
  #   }
  # }

  # Don't care if the mailer can't send
  config.action_mailer.raise_delivery_errors = false

  # Print deprecation notices to the Rails logger
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations
  config.active_record.migration_error = :page_load

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true

  # Generate digests for assets URLs
  # config.assets.digest = false

  config.sass.preferred_syntax = :sass
  Rails.application.routes.default_url_options[:host] = "localhost:3000"
  config.action_mailer.default_url_options = {:host => "localhost:3000"}

  config.after_initialize do
    Bullet.enable = true
    Bullet.bullet_logger = true
    Bullet.console = true
    Bullet.rails_logger = true

    # Added because Branches#show.rss does not use the build_attempts but Branches#show.html does use them
    Bullet.add_whitelist :type => :unused_eager_loading, :class_name => "BuildPart", :association => :build_attempts
  end
end
