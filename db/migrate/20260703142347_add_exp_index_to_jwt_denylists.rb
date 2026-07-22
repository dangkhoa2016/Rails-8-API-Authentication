# frozen_string_literal: true

class AddExpIndexToJwtDenylists < ActiveRecord::Migration[8.0]
  def change
    add_index :jwt_denylists, %i[ jti exp ], name: "index_jwt_denylists_on_jti_and_exp"
  end
end
