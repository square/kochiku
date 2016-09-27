class AddProjectTimeReports < ActiveRecord::Migration
  def change
    create_table :project_time_reports do |t|
      t.integer :repo_id
      t.string :project_name
      t.string :repo_name
      t.integer :ninety_five_pctl_build_wait_time
      t.integer :ninety_pctl_build_wait_time
      t.integer :seventy_pctl_build_wait_time
      t.integer :fifty_pctl_build_wait_time
      t.integer :ninety_five_pctl_build_run_time
      t.integer :ninety_pctl_build_run_time
      t.integer :seventy_pctl_pctl_build_run_time
      t.integer :fifty_pctl_build_run_time
      t.datetime :target_ts, null: false
      t.string :frequency, null: false

      t.timestamps
    end
  end
end
