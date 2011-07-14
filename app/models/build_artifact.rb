class BuildArtifact < ActiveRecord::Base
  belongs_to :build_attempt
  mount_uploader :log_file, LogFileUploader
  validates_presence_of :log_file
end
