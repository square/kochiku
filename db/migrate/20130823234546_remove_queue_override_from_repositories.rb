class RemoveQueueOverrideFromRepositories < ActiveRecord::Migration
  def up
    remove_column :repositories, :queue_override
  end

  def down
    add_column :repositories, :queue_override, :string
  end
end
