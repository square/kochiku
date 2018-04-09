class AddQueueToRepository < ActiveRecord::Migration[5.0]
  def change
    add_column :repositories, :queue_override, :string
  end
end
