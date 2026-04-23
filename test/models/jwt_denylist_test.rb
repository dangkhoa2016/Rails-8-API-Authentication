require "test_helper"

class JwtDenylistTest < ActiveSupport::TestCase
  test "should not save denylist without jti" do
    denylist = JwtDenylist.new
    denylist.exp = Time.now
    assert_not denylist.save, "Saved the denylist without a jti"
  end

  test "should not save denylist without exp" do
    denylist = JwtDenylist.new
    denylist.jti = "123"
    assert_not denylist.save, "Saved the denylist without an exp"
  end

  test "jwt_denylist_count" do
    assert_equal 2, JwtDenylist.count
  end

  test "find one" do
    assert_equal "123", jwt_denylists(:two).jti
  end

  test "delete_expired! removes only records older than cutoff" do
    JwtDenylist.delete_all

    cutoff = Time.current.change(usec: 0)

    expired = JwtDenylist.create!(jti: "expired-jti", exp: cutoff - 1.second)
    boundary = JwtDenylist.create!(jti: "boundary-jti", exp: cutoff)
    active = JwtDenylist.create!(jti: "active-jti", exp: cutoff + 1.hour)

    removed = JwtDenylist.delete_expired!(before: cutoff)

    assert_equal 1, removed
    assert_not JwtDenylist.exists?(expired.id)
    assert JwtDenylist.exists?(boundary.id)
    assert JwtDenylist.exists?(active.id)
  end
end
