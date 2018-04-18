class AddAssumeLostAfterToRepository < ActiveRecord::Migration[5.0]
  def change
    add_column :repositories, :assume_lost_after, :integer
  end
end
