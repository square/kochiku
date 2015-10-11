class RepositoryObserver < ActiveRecord::Observer
  observe :repository

  def after_save(record)
    record.remote_server.install_post_receive_hook!(record) if setup_hook?
  end

  def setup_hook?
    Rails.env.production? || Rails.env.staging?
  end
end
