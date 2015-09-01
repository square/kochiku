require 'base_log_file_uploader'

class LogFileUploader < BaseLogFileUploader
  def store_dir
    build_attempt_id = model.build_attempt_id
    build_part_id = model.build_attempt.build_part_id
    build_id = model.build_attempt.build_part.build_id
    repository_param = model.build_attempt.build_part.build_instance.repository.to_param
    Rails.public_path.join("log_files", repository_param, "build_#{build_id}", "part_#{build_part_id}", "attempt_#{build_attempt_id}")
  end
end
