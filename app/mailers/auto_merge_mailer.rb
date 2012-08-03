class AutoMergeMailer < ActionMailer::Base
  default :from => "kochiku-automerger@corp.squareup.com"

  def merge_successful(email, stdout_and_stderr, merge_ref, build)
    @stdout_and_stderr = stdout_and_stderr
    @merge_ref = merge_ref
    @build = build
    mail(:to => email, :subject => "#{build.ref} Auto Merged")
  end

  def merge_failed(email, stdout_and_stderr, build)
    @stdout_and_stderr = stdout_and_stderr
    @build = build
    mail(:to => email, :subject => "Auto Merge of #{build.ref} Failed")
  end
end
