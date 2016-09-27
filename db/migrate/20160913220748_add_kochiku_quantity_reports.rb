class AddKochikuQuantityReports < ActiveRecord::Migration
  def change
    create_table :kochiku_quantity_reports do |t|
      t.integer :job_number
      t.integer :build_number
      t.datetime :target_ts, null: false
      t.string :frequency, null: false

      t.timestamps
    end
  end
end
