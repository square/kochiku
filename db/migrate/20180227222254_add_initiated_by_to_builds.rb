class AddInitiatedByToBuilds < ActiveRecord::Migration
  def change
    add_column :builds, :initiated_by, :string
  end
end
