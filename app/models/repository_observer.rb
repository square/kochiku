class RepositoryObserver < ActiveRecord::Observer
  observe :repository

  def after_save(record)
    if record.build_pull_requests && should_contact_github?
      GithubPostReceiveHook.new(record).subscribe!
    end
  end

  def should_contact_github?
    Rails.env == "production"
  end
end
