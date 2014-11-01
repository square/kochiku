class AddEmailFirstFailureToRepositories < ActiveRecord::Migration
  def change
    add_column :repositories, :email_on_first_failure, :boolean, default: false, null: false
  end
end
