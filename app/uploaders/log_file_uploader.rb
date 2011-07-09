class LogFileUploader < CarrierWave::Uploader::Base
  storage :file

  def store_dir
    'log_files/'
  end

  def cache_dir
    "#{Rails.root}/tmp/uploads"
  end
end
