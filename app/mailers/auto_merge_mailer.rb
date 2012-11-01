class AutoMergeMailer < ActionMailer::Base
  NOTIFICATIONS_EMAIL = 'kochiku-notifications@squareup.com'

  default :from => "build-and-release+merges@squareup.com"

  def merge_successful(build, stdout_and_stderr)
    @build = build
    @stdout_and_stderr = stdout_and_stderr
    emails = GitBlame.emails_since_last_green(@build)
    mail(:to => emails,
         :bcc => NOTIFICATIONS_EMAIL,
         :subject => "[kochiku] Auto merged #{@build.branch} branch for project #{@build.project.name}")
  end

  def merge_failed(build, stdout_and_stderr)
    @build = build
    @stdout_and_stderr = stdout_and_stderr
    emails = GitBlame.emails_since_last_green(@build)
    mail(:to => emails,
         :bcc => NOTIFICATIONS_EMAIL,
         :subject => "[kochiku] Failed to auto merge #{@build.branch} branch for project #{@build.project.name}")
  end
end
