require 'log_file_uploader'

class BuildArtifact < ActiveRecord::Base
  belongs_to :build_attempt, :inverse_of => :build_artifacts, :touch => true
  mount_uploader :log_file, LogFileUploader
  skip_callback :commit, :after, :remove_log_file!
  validates :log_file, presence: true

  scope :stdout_log, -> { where(:log_file => ['stdout.log.gz', 'stdout.log']) }
  scope :error_txt, -> { where(:log_file => 'error.txt') }

  def as_json
    super(except: "log_file").tap do |hash|
      log_file = {"url" => Rails.application.routes.url_helpers.build_artifact_path(self), "name" => self.log_file.path}
      hash["build_artifact"]["log_file"] = log_file
    end
  end
end
