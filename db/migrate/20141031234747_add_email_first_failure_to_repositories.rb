class AddEmailFirstFailureToRepositories < ActiveRecord::Migration[5.1]
  def change
    add_column :repositories, :email_on_first_failure, :boolean, default: false, null: false
  end
end
