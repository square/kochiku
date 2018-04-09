class RemoveQueueOverrideFromRepositories < ActiveRecord::Migration[5.1]
  def up
    remove_column :repositories, :queue_override
  end

  def down
    add_column :repositories, :queue_override, :string
  end
end
