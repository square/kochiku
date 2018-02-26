class AddAssumeLostAfterToRepository < ActiveRecord::Migration
  def change
    add_column :repositories, :assume_lost_after, :integer
  end
end
