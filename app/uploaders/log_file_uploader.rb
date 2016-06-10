require 'base_log_file_uploader'

class LogFileUploader < BaseLogFileUploader
  def store_dir
    build_attempt_id = model.build_attempt_id
    build_part_id = model.build_attempt.build_part_id
    build_id = model.build_attempt.build_part.build_id

    # temporary backwards compatibility for old build artifacts created before the deploy on 08/25/2015
    if model.build_attempt.created_at < Time.parse("2015-08-25 04:12:46 UTC").utc &&
       (project_id = model.build_attempt.build_part.build_instance.project_id)
      project_param = ActiveRecord::Base.connection.select_value("select name from projects where id = #{project_id}")
      return File.join(project_param, "build_#{build_id}", "part_#{build_part_id}", "attempt_#{build_attempt_id}")
    end

    repository_param = model.build_attempt.build_part.build_instance.repository.to_param
    Rails.public_path.join("log_files", repository_param, "build_#{build_id}", "part_#{build_part_id}", "attempt_#{build_attempt_id}")
  end
end
