# frozen_string_literal: true

require "test_helper"

class SeedsTest < ActiveSupport::TestCase
  class SeedUser
    attr_reader :password_writes, :confirm_calls, :save_calls, :attribute_writes

    def initialize(new_record:)
      @new_record = new_record
      @password_writes = 0
      @confirm_calls = 0
      @save_calls = 0
      @attribute_writes = 0
    end

    def new_record?
      @new_record
    end

    def assign_attributes(_attributes)
      @attribute_writes += 1
    end

    def password=(_value)
      @password_writes += 1
    end

    def confirm
      @confirm_calls += 1
    end

    def save!
      @save_calls += 1
    end
  end

  def run_seed
    Object.new.instance_eval(File.read(Rails.root.join("db/seeds.rb")), "db/seeds.rb", 1)
  end

  test "a new development admin gets a generated password and is confirmed and saved once" do
    user = SeedUser.new(new_record: true)

    out, = capture_io do
      SecureRandom.stub(:hex, "abc123def456") do
        Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new("development")) do
          User.stub(:find_or_initialize_by, ->(*_args, **_kwargs) { user }) { run_seed }
        end
      end
    end

    assert_equal 1, user.attribute_writes
    assert_equal 1, user.password_writes
    assert_equal 1, user.confirm_calls
    assert_equal 1, user.save_calls
    assert_includes out, "abc123def456-Admin1Dev!"
    assert_includes out, "Admin user created"
  end

  test "a new production admin uses configured credentials once without printing the secret" do
    user = SeedUser.new(new_record: true)
    env_vars = { "ADMIN_EMAIL" => "admin@example.com", "ADMIN_PASSWORD" => "super_secret" }

    out, = capture_io do
      Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new("production")) do
        ENV.stub(:[], ->(key) { env_vars[key] }) do
          User.stub(:find_or_initialize_by, ->(*_args, **_kwargs) { user }) { run_seed }
        end
      end
    end

    assert_equal 1, user.attribute_writes
    assert_equal 1, user.password_writes
    assert_equal 1, user.confirm_calls
    assert_equal 1, user.save_calls
    assert_includes out, "using provided credentials"
    assert_not_includes out, "super_secret"
  end

  test "an existing production admin leaves credentials and attributes unchanged" do
    user = SeedUser.new(new_record: false)
    env_vars = { "ADMIN_EMAIL" => "admin@example.com", "ADMIN_PASSWORD" => "super_secret" }

    out, = capture_io do
      Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new("production")) do
        ENV.stub(:[], ->(key) { env_vars[key] }) do
          User.stub(:find_or_initialize_by, ->(*_args, **_kwargs) { user }) { run_seed }
        end
      end
    end

    assert_equal 0, user.attribute_writes
    assert_equal 0, user.password_writes
    assert_equal 0, user.confirm_calls
    assert_equal 0, user.save_calls
    assert_includes out, "Admin user already exists; credentials left unchanged."
    assert_not_includes out, "super_secret"
  end
end
