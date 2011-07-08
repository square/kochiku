class BuildArtifact < ActiveRecord::Base
  belongs_to :build_part_result
  mount_uploader :log_file, LogFileUploader
end
