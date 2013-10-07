if defined?(Bullet)
  Bullet.enable = true
  Bullet.bullet_logger = true
  Bullet.console = true unless Rails.env.test? # this poops on the DOM and capybara flips out

  # Added because Projects#show.rss does not use the build_attempts but Projects#show.html does use them
  Bullet.add_whitelist :type => :unused_eager_loading, :class_name => "BuildPart", :association => :build_attempts
end
