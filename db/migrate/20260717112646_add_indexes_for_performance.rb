class AddIndexesForPerformance < ActiveRecord::Migration[8.1]
  def change
    add_index :users, :role
    add_index :users, :active
  end
end
