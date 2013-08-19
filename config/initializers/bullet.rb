if defined?(Bullet)
  Bullet.enable = true
  Bullet.bullet_logger = true
  Bullet.console = true unless Rails.env.test? # this poops on the DOM and capybara flips out
  Bullet.rails_logger = true
end
