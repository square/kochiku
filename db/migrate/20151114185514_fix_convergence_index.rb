# In order for the index on convergence col to be useful it needs to be
# namespaced by repository_id
class FixConvergenceIndex < ActiveRecord::Migration[5.0]
  def change
    # Add the new index first to avoid killing performance
    add_index :branches, [:repository_id, :convergence]
    remove_index :branches, column: :convergence
  end
end
