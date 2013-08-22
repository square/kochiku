class AutoMergeMailer < ActionMailer::Base
  helper :application

  default :from => Proc.new { Settings.sender_email_address }

  def merge_successful(build, emails, stdout_and_stderr)
    @build = build
    @stdout_and_stderr = stdout_and_stderr
    mail(:to => emails,
         :bcc => Settings.kochiku_notifications_email_address,
         :subject => "[kochiku] Auto merged #{@build.branch} branch for project #{@build.project.name}")
  end

  def merge_failed(build, emails, stdout_and_stderr)
    @build = build
    @stdout_and_stderr = stdout_and_stderr
    mail(:to => emails,
         :bcc => Settings.kochiku_notifications_email_address,
         :subject => "[kochiku] Failed to auto merge #{@build.branch} branch for project #{@build.project.name}")
  end
end
