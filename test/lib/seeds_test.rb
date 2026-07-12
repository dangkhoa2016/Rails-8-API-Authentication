# frozen_string_literal: true

require "test_helper"

class SeedsTest < ActiveSupport::TestCase
  def setup
    @admin_user = Object.new
    def @admin_user.password=(_value); end
    def @admin_user.confirm; end
    def @admin_user.save!; end
  end

  def run_seed
    Object.new.instance_eval(File.read(Rails.root.join("db/seeds.rb")), "db/seeds.rb", 1)
  end

  test "in development the seed reports the auto-generated password instead of provided credentials" do
    out, = capture_io do
      SecureRandom.stub(:hex, "abc123def456") do
        Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new("development")) do
          User.stub(:find_or_create_by, ->(*_args, **_kwargs) { @admin_user }) do
            run_seed
          end
        end
      end
    end

    assert_includes out, "Admin user created"
    assert_includes out, "abc123def456-Admin1Dev!"
    assert_includes out, "generated"
    assert_not_includes out, "using provided credentials"
  end

  test "outside development the seed reports the configured credentials source" do
    env_vars = { "ADMIN_EMAIL" => "admin@example.com", "ADMIN_PASSWORD" => "super_secret" }
    out, = capture_io do
      Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new("production")) do
        ENV.stub(:[], ->(key) { env_vars[key] }) do
          User.stub(:find_or_create_by, ->(*_args, **_kwargs) { @admin_user }) do
            run_seed
          end
        end
      end
    end

    assert_includes out, "Admin user created"
    assert_includes out, "using provided credentials"
    assert_not_includes out, "super_secret"
    assert_not_includes out, "generated"
  end
end
