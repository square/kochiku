class AddInitiatedByToBuilds < ActiveRecord::Migration[5.0]
  def change
    add_column :builds, :initiated_by, :string
  end
end
