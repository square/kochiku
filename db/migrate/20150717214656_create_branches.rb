class CreateBranches < ActiveRecord::Migration[5.0]
  def change
    create_table :branches do |t|
      t.references :repository, null: false
      t.string :name, null: false
      t.boolean :convergence, null: false, default: false
      t.timestamps null: false

      t.index([:repository_id, :name], unique: true)
      t.index(:convergence)
    end

    change_table :builds do |t|
      t.references :branch, index: true
      t.index([:ref, :branch_id], unique: true)
    end
  end
end
