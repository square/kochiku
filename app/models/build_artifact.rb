class BuildArtifact < ActiveRecord::Base
  belongs_to :build_attempt
  mount_uploader :log_file, LogFileUploader
end
