class BuildMailer < ActionMailer::Base
  helper :application

  default :from => Proc.new { Settings.sender_email_address }

  def error_email(build_attempt, error_text = nil)
    @build_part = build_attempt.build_part
    @builder = build_attempt.builder
    @error_text = error_text
    mail :to => Settings.kochiku_notifications_email_address,
         :subject => "[kochiku] Build part errored on #{@builder}",
         :from => Settings.sender_email_address
  end

  def build_break_email(build)
    @build = build
    if @build.project.main?
      @emails = GitBlame.emails_since_last_green(@build)
      @git_changes = GitBlame.changes_since_last_green(@build)
    else
      @emails = GitBlame.emails_in_branch(@build)
      @git_changes = GitBlame.changes_in_branch(@build)
    end

    @failed_build_parts = @build.build_parts.failed_or_errored

    mail :to => @emails,
         :bcc => Settings.kochiku_notifications_email_address,
         :subject => "[kochiku] #{@build.project.name} build for branch #{@build.branch} failed",
         :from => Settings.sender_email_address
  end

  def build_success_email(build)
    @build = build
    @email = GitBlame.emails_in_branch(@build).first
    @git_changes = GitBlame.changes_in_branch(@build)

    mail :to => @email,
         :bcc => Settings.kochiku_notifications_email_address,
         :subject => "[kochiku] #{@build.project.name} build for branch #{@build.branch} passed",
         :from => Settings.sender_email_address
  end
end
