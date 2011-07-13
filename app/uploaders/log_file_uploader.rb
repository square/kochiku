class LogFileUploader < CarrierWave::Uploader::Base
  storage :file

  def store_dir
    build_part_result_id = model.build_part_result_id
    build_part_id = model.build_part_result.build_part_id
    build_id = model.build_part_result.build_part.build_id
    Rails.root.join("public", "log_files", "build_#{build_id}", "part_#{build_part_id}", "result_#{build_part_result_id}")
  end

  def cache_dir
    Rails.root.join('tmp', 'uploads')
  end
end
