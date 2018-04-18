class RecordBuildFailureEmailSent < ActiveRecord::Migration[5.0]
  def change
    add_column :builds, :build_failure_email_sent, :boolean
  end
end
