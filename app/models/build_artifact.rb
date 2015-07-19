require 'log_file_uploader'

class BuildArtifact < ActiveRecord::Base
  belongs_to :build_attempt, :inverse_of => :build_artifacts, :touch => true
  mount_uploader :log_file, LogFileUploader
  skip_callback :commit, :after, :remove_log_file!
  validates_presence_of :log_file

  scope :stdout_log, -> { where(:log_file => ['stdout.log.gz', 'stdout.log']) }
  scope :junit_log, -> { where(:log_file => 'rspec.xml.log.gz') }
  scope :error_txt, -> { where(:log_file => 'error.txt') }
end
