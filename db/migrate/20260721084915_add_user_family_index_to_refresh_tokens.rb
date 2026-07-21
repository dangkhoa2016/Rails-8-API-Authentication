# frozen_string_literal: true

class AddUserFamilyIndexToRefreshTokens < ActiveRecord::Migration[8.1]
  def change
    add_index :refresh_tokens, %i[user_id family_id]
  end
end
