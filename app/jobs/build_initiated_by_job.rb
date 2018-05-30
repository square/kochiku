require 'job_base'
require 'git_repo'

class BuildInitiatedByJob < JobBase
  extend Resque::Plugins::Retry
  @queue = :low

  @retry_limit = 5
  @retry_exceptions = {GitRepo::RefNotFoundError => [60, 60, 60, 180, 360],
                       Cocaine::ExitStatusError => [30, 60, 60, 60, 60] }

  def initialize(build_id)
    @build = Build.find(build_id)
  end

  def perform
    return if @build.initiated_by
    email = GitBlame.last_email_in_branch(@build).first
    if email.present?
      @build.update_attributes(initiated_by: email)
    end
  end
end
