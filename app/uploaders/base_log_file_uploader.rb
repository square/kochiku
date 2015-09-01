class BaseLogFileUploader < CarrierWave::Uploader::Base
  storage :file

  def cache_dir
    Rails.root.join('tmp', 'uploads')
  end
end
