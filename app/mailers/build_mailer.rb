class BuildMailer < ActionMailer::Base
  helper :application

  default :from => Proc.new { Settings.sender_email_address }

  def pull_request_link(build)
    @build = build

    remote_server = @build.repository.remote_server
    if remote_server.class == RemoteServer::Stash && @build.project.name =~ /-pull_requests$/
      begin
        id, version = remote_server.get_pr_id_and_version(@build.branch)
        return "#{remote_server.base_html_url}/pull-requests/#{id}/overview"
      rescue RemoteServer::StashAPIError
        return nil
      end
    end
    nil
  end

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

    # Allow the partitioner to be selective about who is emailed
    partitioner = Partitioner.for_build(@build)
    @responsible_email_and_files = partitioner.emails_for_commits_causing_failures
    @emails = @responsible_email_and_files.keys
    if @emails.empty?
      if @build.project.main?
        @emails = GitBlame.emails_since_last_green(@build)
      else
        @emails = GitBlame.emails_in_branch(@build)
      end
    end

    if @build.project.main?
      @git_changes = GitBlame.changes_since_last_green(@build)
    else
      @git_changes = GitBlame.changes_in_branch(@build)
    end

    @failed_build_parts = @build.build_parts.failed_or_errored
    @pr_link = pull_request_link(build)

    mail :to => @emails,
         :bcc => Settings.kochiku_notifications_email_address,
         :subject => "[kochiku] Failure - #{@build.branch} build for #{@build.project.name}",
         :from => Settings.sender_email_address
  end

  def build_success_email(build)
    @build = build
    @email = GitBlame.last_email_in_branch(@build)
    @git_changes = GitBlame.changes_in_branch(@build)
    @pr_link = pull_request_link(build)

    mail :to => @email,
         :bcc => Settings.kochiku_notifications_email_address,
         :subject => "[kochiku] Success - #{@build.branch} build for #{@build.project.name}",
         :from => Settings.sender_email_address
  end
end
