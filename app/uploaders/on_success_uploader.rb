require 'base_log_file_uploader'

class OnSuccessUploader < BaseLogFileUploader
  def store_dir
    build_id = model.id
    repository_param = model.repository.to_param
    Rails.root.join("public", "log_files", repository_param, "build_#{build_id}")
  end
end
