class BuildPartTimeOutMailer < ActionMailer::Base
  BULID_AND_RELEASE = 'bulid-and-release@squareup.com'

  def send(build_part)
    @build_part = build_part
    @builder = build_part.build_attempts.last.builder
    mail(:to => BULID_AND_RELEASE, :subject => "[kochiku] Build part timed out")
  end
end
