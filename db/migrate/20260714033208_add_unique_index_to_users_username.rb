# frozen_string_literal: true

class AddUniqueIndexToUsersUsername < ActiveRecord::Migration[8.1]
  def change
    add_index :users, :username, unique: true, name: "index_users_on_username"
  end
end
