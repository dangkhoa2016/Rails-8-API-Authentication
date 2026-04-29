class AllowNilUsernames < ActiveRecord::Migration[8.0]
  def up
    change_column_null :users, :username, true
    change_column_default :users, :username, from: "", to: nil

    execute <<~SQL
      UPDATE users
      SET username = NULL
      WHERE TRIM(username) = ''
    SQL
  end

  def down
    execute <<~SQL
      UPDATE users
      SET username = ''
      WHERE username IS NULL
    SQL

    change_column_null :users, :username, false
    change_column_default :users, :username, from: nil, to: ""
  end
end
