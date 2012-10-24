class RecordBuildFailureEmailSent < ActiveRecord::Migration
  def change
    add_column :builds, :build_failure_email_sent, :boolean
  end
end
