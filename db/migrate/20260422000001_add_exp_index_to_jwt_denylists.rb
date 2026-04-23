class AddExpIndexToJwtDenylists < ActiveRecord::Migration[8.0]
  def change
    add_index :jwt_denylists, :exp, name: "index_jwt_denylists_on_exp"
  end
end
