class LogFileUploader < CarrierWave::Uploader::Base
  storage :file

  def store_dir
    'log_files/'
  end
end
