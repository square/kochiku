class AddQueueToRepository < ActiveRecord::Migration
  def change
    add_column :repositories, :queue_override, :string
  end
end
