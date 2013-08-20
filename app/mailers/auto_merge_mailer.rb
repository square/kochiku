class AutoMergeMailer < ActionMailer::Base
  helper :application

  default :from => Proc.new { Settings.sender_email_address }

  def merge_successful(build, emails, stdout_and_stderr)
    @build = build
    @stdout_and_stderr = stdout_and_stderr
    mail(:to => emails,
         :subject => "[kochiku] Auto merged #{@build.branch} branch for project #{@build.project.name}")
  end

  def merge_failed(build, emails, stdout_and_stderr)
    @build = build
    @stdout_and_stderr = stdout_and_stderr
    mail(:to => emails,
         :subject => "[kochiku] Failed to auto merge #{@build.branch} branch for project #{@build.project.name}")
  end
end
