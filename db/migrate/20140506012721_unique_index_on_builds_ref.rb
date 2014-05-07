class UniqueIndexOnBuildsRef < ActiveRecord::Migration
  def up
    remove_index :builds, column: :ref

    # set length to 40 characters and add not null constraint
    change_column :builds, :ref, :string, { limit: 40, null: false }

    add_index :builds, [:ref, :project_id], :unique => true
  end

  def down
    remove_index :builds, column: [:ref, :project_id]

    change_column :builds, :ref, :string

    add_index :builds, :ref
  end
end
