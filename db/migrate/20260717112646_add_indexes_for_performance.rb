class AddIndexesForPerformance < ActiveRecord::Migration[8.0]
  def change
    add_index :users, :role
    add_index :users, :active
  end
end
