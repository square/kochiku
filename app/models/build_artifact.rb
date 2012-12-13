require 'log_file_uploader'

class BuildArtifact < ActiveRecord::Base
  belongs_to :build_attempt, :inverse_of => :build_artifacts
  mount_uploader :log_file, LogFileUploader
  validates_presence_of :log_file
end
