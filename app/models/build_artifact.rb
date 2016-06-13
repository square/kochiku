require 'log_file_uploader'

class BuildArtifact < ActiveRecord::Base
  belongs_to :build_attempt, :inverse_of => :build_artifacts, :touch => true
  mount_uploader :log_file, LogFileUploader
  skip_callback :commit, :after, :remove_log_file!
  validates :log_file, presence: true

  scope :stdout_log, -> { where(:log_file => ['stdout.log.gz', 'stdout.log']) }
  scope :error_txt, -> { where(:log_file => 'error.txt') }

  def log_contents
    if log_file.path.include? '.gz'
      Zlib::GzipReader.new(open(log_file.path)).read
    else
      log_file.read
    end
  end
end
