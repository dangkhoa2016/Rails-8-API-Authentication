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
end
