class RepositoryObserver < ActiveRecord::Observer
  observe :repository

  def after_save(record)
    if setup_hook?
      record.remote_server.install_post_receive_hook!(record)
    end
  end

  def setup_hook?
    Rails.env.production? || Rails.env.staging?
  end
end
