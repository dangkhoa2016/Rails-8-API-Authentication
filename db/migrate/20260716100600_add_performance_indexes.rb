# frozen_string_literal: true

class AddPerformanceIndexes < ActiveRecord::Migration[8.1]
  def change
    add_index :users, :role
    add_index :users, :active
    add_index :jwt_denylists, :exp
  end
end
