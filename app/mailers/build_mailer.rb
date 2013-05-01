class BuildMailer < ActionMailer::Base
  helper :application
  NOTIFICATIONS_EMAIL = 'kochiku-notifications@squareup.com'
  KOCHIKU_EMAIL = 'build-and-release@squareup.com'

  default :from => KOCHIKU_EMAIL

  def time_out_email(build_attempt)
    @build_part = build_attempt.build_part
    @builder = build_attempt.builder
    mail :to => NOTIFICATIONS_EMAIL,
         :subject => "[kochiku] Build part timed out",
         :from => 'build-and-release+timeouts@squareup.com'
  end

  def error_email(build_attempt, error_text = nil)
    @build_part = build_attempt.build_part
    @builder = build_attempt.builder
    @error_text = error_text
    mail :to => NOTIFICATIONS_EMAIL,
         :subject => "[kochiku] Build part errored on #{@builder}",
         :from => 'build-and-release+errors@squareup.com'
  end

  def build_break_email(build)
    @build = build
    if @build.project.main_build?
      if @build.project.name == "java"
        @emails = MavenPartitioner.emails_for_commits_causing_failures(@build)
      else
        @emails = GitBlame.emails_since_last_green(@build)
      end
      @git_changes = GitBlame.changes_since_last_green(@build)
    else
      @emails = GitBlame.emails_in_branch(@build)
      @git_changes = GitBlame.changes_in_branch(@build)
    end

    @failed_build_parts = @build.build_parts.failed_or_errored

    mail :to => @emails,
         :bcc => NOTIFICATIONS_EMAIL,
         :subject => "[kochiku] #{@build.project.name} build for branch #{@build.branch} failed",
         :from => "build-and-release+#{@build.project.name.parameterize}@squareup.com"
  end
end
