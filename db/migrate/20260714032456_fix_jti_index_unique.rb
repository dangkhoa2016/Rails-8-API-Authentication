# frozen_string_literal: true

class FixJtiIndexUnique < ActiveRecord::Migration[8.1]
  def change
    remove_index :jwt_denylists, name: "index_jwt_denylists_on_jti"
    add_index :jwt_denylists, :jti, unique: true
  end
end
