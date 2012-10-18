class BuildPartMailer < ActionMailer::Base
  TIMEOUT_EMAIL = 'build-and-release+timeouts@squareup.com'
  KOCHIKU_EMAIL = 'kochiku@squareup.com'

  default :from => KOCHIKU_EMAIL

  def time_out_email(build_part)
    @build_part = build_part
    @builder = build_part.build_attempts.last.builder
    mail(:to => TIMEOUT_EMAIL, :subject => "[kochiku] Build part timed out")
  end

  def build_break_email(emails, build_part)
    @build_part = build_part
    mail(:to => emails | ["cheister@squareup.com"],
         :subject => "[kochiku] Build part failed for #{build_part.project.name}")
  end
end
