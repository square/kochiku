require 'log_file_uploader'

class BuildArtifact < ActiveRecord::Base
  belongs_to :build_attempt, :inverse_of => :build_artifacts
  mount_uploader :log_file, LogFileUploader
  validates_presence_of :log_file

  scope :stdout, where(:log_file => ['stdout.log.gz', 'stdout.log'])
  scope :junit, where(:log_file => 'rspec.xml.log.gz')
end
