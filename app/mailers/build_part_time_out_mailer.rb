class BuildPartTimeOutMailer < ActionMailer::Base
  BUILD_AND_RELEASE = 'build-and-release+timeouts@squareup.com'

  default :from => BUILD_AND_RELEASE

  def time_out_email(build_part)
    @build_part = build_part
    @builder = build_part.build_attempts.last.builder
    mail(:to => BUILD_AND_RELEASE,
         :subject => "[kochiku] Build part timed out",
         :from => 'kochiku@squareup.com').deliver
  end
end
