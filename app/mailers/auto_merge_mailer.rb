class AutoMergeMailer < ActionMailer::Base
  default :from => "kochiku-automerger@corp.squareup.com"

  def merge_successful(email, stdout_and_stderr, build)
    @stdout_and_stderr = stdout_and_stderr
    @build = build
    mail(:to => email, :subject => "#{build.branch_or_ref} Auto Merged")
  end

  def merge_failed(email, stdout_and_stderr, build)
    @stdout_and_stderr = stdout_and_stderr
    @build = build
    mail(:to => email, :subject => "Auto Merge of #{build.branch_or_ref} Failed")
  end
end
