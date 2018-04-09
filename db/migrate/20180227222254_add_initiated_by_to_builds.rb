class AddInitiatedByToBuilds < ActiveRecord::Migration[5.1]
  def change
    add_column :builds, :initiated_by, :string
  end
end
