class AddProjectQuantityReports < ActiveRecord::Migration
  def change
    create_table :project_quantity_reports do |t|
      t.integer :repo_id
      t.string :repo_name
      t.string :project_name
      t.integer :job_number
      t.integer :build_number
      t.datetime :target_ts, null: false
      t.string :frequency, null: false

      t.timestamps
    end
  end
end
