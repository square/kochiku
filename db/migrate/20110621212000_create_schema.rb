class CreateSchema < ActiveRecord::Migration
  def self.up
    create_table :builds do |t|
      t.string :sha
      t.string :state
      t.string :queue

      t.timestamps(null: false)
    end

    create_table :build_parts do |t|
      t.integer :build_id
      t.string :kind
      t.text :paths

      t.timestamps(null: false)
    end

    create_table :build_part_results do |t|
      t.integer :build_part_id
      t.datetime :started_at
      t.datetime :finished_at
      t.string :builder
      t.string :result

      t.timestamps(null: false)
    end

    create_table :build_artifacts do |t|
      t.integer :build_part_result_id
      t.string :type
      t.text :content

      t.timestamps(null: false)
    end

  end

  def self.down
    drop_table :build_artifacts
    drop_table :build_part_results
    drop_table :build_parts
    drop_table :builds
  end
end
