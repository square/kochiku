class MergeMailer < ActionMailer::Base
  helper :application

  default :from => Proc.new { Settings.sender_email_address }

  def merge_successful(build, merge_commit, emails, stdout_and_stderr)
    @build = build
    @merge_commit = merge_commit
    @stdout_and_stderr = stdout_and_stderr

    mail(:to => emails,
         :bcc => Settings.kochiku_notifications_email_address,
         :subject => "[kochiku] Merged #{@build.branch_record.name} branch for #{@build.repository.name}")
  end

  def merge_failed(build, emails, stdout_and_stderr)
    @build = build
    @stdout_and_stderr = stdout_and_stderr
    mail(:to => emails,
         :bcc => Settings.kochiku_notifications_email_address,
         :subject => "[kochiku] Failed to merge #{@build.branch_record.name} branch for #{@build.repository.name}")
  end
end
