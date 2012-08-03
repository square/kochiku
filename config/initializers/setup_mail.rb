ActionMailer::Base.delivery_method = :smtp
ActionMailer::Base.smtp_settings = {
  :address              => "daisy.corp.squareup.com",
  :port                 => 25
}
