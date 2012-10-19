class BuildPartMailer < ActionMailer::Base
  TIMEOUT_EMAIL = 'build-and-release+timeouts@squareup.com'
  KOCHIKU_EMAIL = 'kochiku@squareup.com'

  default :from => KOCHIKU_EMAIL

  def time_out_email(build_part)
    @build_part = build_part
    @builder = build_part.build_attempts.last.builder
    mail(:to => TIMEOUT_EMAIL, :subject => "[kochiku] Build part timed out")
  end

  def build_break_email(emails, build_attempt)
    @build_part = build_attempt.build_part
    @artifacts = build_attempt.build_artifacts.reject { |artifact| artifact.log_file.path =~ /\.xml\.gz/ }
    @git_changes = GitBlame.git_changes_since_last_green(@build_part.build_instance)

    @stdout_url = "http://macbuild-master.sfo.squareup.com/log_files/#{@build_part.project.to_param}/build_#{@build_part.build_instance.id}/part_#{@build_part.id}/attempt_#{build_attempt.id}/stdout.log.gz"

    #TODO: only temporary for testing, we'll send to these emails once we're happy with the frequency and email formatting
    @emails = emails

    mail(:to => ["cheister@squareup.com"],
         :bcc => ["nolan@squareup.com", "ssorrell@squareup.com"],
         :subject => "[kochiku] Build part failed for #{@build_part.project.name}")
  end
end
