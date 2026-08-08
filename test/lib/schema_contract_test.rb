# frozen_string_literal: true

require "test_helper"

class SchemaContractTest < ActiveSupport::TestCase
  def connection
    ActiveRecord::Base.connection
  end

  def index(table, columns)
    connection.indexes(table).find { |candidate| candidate.columns == Array(columns).map(&:to_s) }
  end

  test "critical uniqueness is enforced by PostgreSQL" do
    assert index(:users, :email)&.unique
    assert index(:users, :username)&.unique
    assert index(:jwt_denylists, :jti)&.unique
    assert index(:refresh_tokens, :token_digest)&.unique
  end

  test "refresh tokens retain their user foreign key" do
    foreign_key = connection.foreign_keys(:refresh_tokens).find { |key| key.to_table == "users" }

    assert foreign_key
  end

  test "required defaults and null constraints are preserved" do
    user_columns = connection.columns(:users).index_by(&:name)
    token_columns = connection.columns(:refresh_tokens).index_by(&:name)

    assert_equal false, user_columns.fetch("active").null
    assert_equal true, user_columns.fetch("active").default
    assert_equal false, user_columns.fetch("role").null
    assert_equal "user", user_columns.fetch("role").default
    %w[user_id token_digest family_id expires_at].each do |name|
      assert_equal false, token_columns.fetch(name).null
    end
  end

  test "cleanup and family queries have supporting indexes" do
    assert index(:jwt_denylists, %i[jti exp])
    assert index(:refresh_tokens, :expires_at)
    assert index(:refresh_tokens, %i[user_id family_id])
  end
end
