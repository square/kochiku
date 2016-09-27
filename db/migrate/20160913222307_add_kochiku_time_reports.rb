class AddKochikuTimeReports < ActiveRecord::Migration
  def change
    create_table :kochiku_time_reports do |t|
      t.integer :ninety_five_pctl_job_wait_time
      t.integer :ninety_pctl_job_wait_time
      t.integer :seventy_pctl_job_wait_time
      t.integer :fifty_pctl_job_wait_time
      t.datetime :target_ts, null: false
      t.string :frequency, null: false

      t.timestamps
    end
  end
end
