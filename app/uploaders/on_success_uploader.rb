class OnSuccessUploader < CarrierWave::Uploader::Base
  storage :file

  def store_dir
    build_id = model.id
    repository_param = model.repository.to_param
    Rails.root.join("public", "log_files", repository_param, "build_#{build_id}")
  end

  def cache_dir
    Rails.root.join('tmp', 'uploads')
  end
end
