# frozen_string_literal: true

require "test_helper"

class RefreshTokenTest < ActiveSupport::TestCase
  setup do
    @user = confirmed_user("refresh_token_test@example.com", first_name: "Refresh", last_name: "Token")
  end

  test "generate_for creates a record with a raw token and digest" do
    raw_token, record = RefreshToken.generate_for(@user, user_agent: "RSpec", ip_address: "127.0.0.1")

    assert_equal RefreshToken.digest(raw_token), record.token_digest
    assert_not_nil record.family_id
    assert record.expires_at > Time.current
    assert_equal "RSpec", record.user_agent
    assert_equal "127.0.0.1", record.ip_address
    assert_equal @user, record.user
  end

  test "generate_for respects a provided family_id" do
    family_id = SecureRandom.uuid
    _raw, record = RefreshToken.generate_for(@user, family_id: family_id)

    assert_equal family_id, record.family_id
  end

  test "token digests are unique" do
    raw_one, = RefreshToken.generate_for(@user)
    _raw_two, record_two = RefreshToken.generate_for(@user)

    assert_not_equal RefreshToken.digest(raw_one), record_two.token_digest
  end

  test "find_by_raw_token finds the record by digest" do
    raw_token, record = RefreshToken.generate_for(@user)

    found = RefreshToken.find_by_raw_token(raw_token)

    assert_equal record.id, found.id
  end

  test "find_by_raw_token returns nil for blank or unknown tokens" do
    assert_nil RefreshToken.find_by_raw_token(nil)
    assert_nil RefreshToken.find_by_raw_token("")
    assert_nil RefreshToken.find_by_raw_token("unknown-token")
  end

  test "active? is true for an unused, unexpired token" do
    _raw, record = RefreshToken.generate_for(@user)

    assert record.active?
    assert_not record.expired?
    assert_not record.revoked?
  end

  test "revoke! marks the token revoked" do
    _raw, record = RefreshToken.generate_for(@user)

    record.revoke!

    assert record.revoked?
    assert_not record.active?
    assert_not_nil record.revoked_at
  end

  test "revoke! is idempotent" do
    _raw, record = RefreshToken.generate_for(@user)

    record.revoke!
    revoked_at = record.revoked_at
    record.revoke!

    assert_equal revoked_at, record.revoked_at
  end

  test "revoke_family! revokes every active token in the family" do
    family_id = SecureRandom.uuid
    _raw, record = RefreshToken.generate_for(@user, family_id: family_id)
    other = RefreshToken.generate_for(@user, family_id: family_id)
    other_family = RefreshToken.generate_for(@user)

    record.revoke_family!

    assert RefreshToken.find(record.id).revoked?
    assert RefreshToken.find(other[1].id).revoked?
    assert_not RefreshToken.find(other_family[1].id).revoked?
  end

  test "validates required attributes" do
    token = RefreshToken.new

    assert_not token.valid?
    assert_includes token.errors[:token_digest], "can't be blank"
    assert_includes token.errors[:family_id], "can't be blank"
    assert_includes token.errors[:expires_at], "can't be blank"
  end

  test "active scope returns only live tokens" do
    RefreshToken.delete_all

    _live = RefreshToken.generate_for(@user)
    _dead, dead_record = RefreshToken.generate_for(@user)
    dead_record.update!(expires_at: 1.hour.ago)
    _revoked, revoked_record = RefreshToken.generate_for(@user)
    revoked_record.revoke!

    assert_equal 1, RefreshToken.active.count
  end

  test "expired scope returns only expired tokens" do
    RefreshToken.delete_all

    _live, live_record = RefreshToken.generate_for(@user)
    _dead, dead_record = RefreshToken.generate_for(@user)
    dead_record.update!(expires_at: 1.hour.ago)

    assert_equal 1, RefreshToken.expired.count
    assert_equal dead_record.id, RefreshToken.expired.first.id
  end

  test "revoked scope returns only revoked tokens" do
    RefreshToken.delete_all

    _live = RefreshToken.generate_for(@user)
    _revoked, revoked_record = RefreshToken.generate_for(@user)
    revoked_record.revoke!

    assert_equal 1, RefreshToken.revoked.count
  end

  test "rotate creates one successor in the same family" do
    raw, record = RefreshToken.generate_for(@user)
    status, new_raw, successor = record.rotate!(user_agent: "agent", ip_address: "192.0.2.10")
    assert_equal :rotated, status
    assert_not_equal raw, new_raw
    assert record.reload.revoked?
    assert_equal record.family_id, successor.family_id
    assert_equal successor, RefreshToken.find_by_raw_token(new_raw)
  end

  test "rotate creates no successor for revoked token" do
    _raw, record = RefreshToken.generate_for(@user)
    record.revoke!
    assert_no_difference("RefreshToken.count") { assert_equal [ :revoked, nil, nil ], record.rotate! }
  end

  test "rotate revokes expired token without successor" do
    _raw, record = RefreshToken.generate_for(@user)
    record.update!(expires_at: 1.hour.ago)
    assert_no_difference("RefreshToken.count") { assert_equal [ :expired, nil, nil ], record.rotate! }
    assert record.reload.revoked?
  end

  test "family revocation is isolated by user" do
    family = SecureRandom.uuid
    _raw, record = RefreshToken.generate_for(@user, family_id: family)
    other = confirmed_user("other-family@example.com", first_name: "Other", last_name: "Family")
    _other_raw, other_record = RefreshToken.generate_for(other, family_id: family)
    record.revoke_family!
    assert record.reload.revoked?
    assert_not other_record.reload.revoked?
  end
end
