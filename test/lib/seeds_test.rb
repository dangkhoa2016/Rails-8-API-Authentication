# frozen_string_literal: true

require "test_helper"

class SeedsTest < ActiveSupport::TestCase
  class FakeAdminUser
    attr_reader :assigned_attributes, :password_writes, :confirm_calls, :save_calls

    def initialize(new_record:)
      @new_record = new_record
      @assigned_attributes = {}
      @password_writes = 0
      @confirm_calls = 0
      @save_calls = 0
    end

    def new_record?
      @new_record
    end

    def assign_attributes(**attributes)
      @assigned_attributes.merge!(attributes)
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

  test "in development a new admin reports the auto-generated password" do
    admin = FakeAdminUser.new(new_record: true)

    out, = capture_io do
      SecureRandom.stub(:hex, "abc123def456") do
        Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new("development")) do
          User.stub(:find_or_initialize_by, ->(*_args, **_kwargs) { admin }) do
            run_seed
          end
        end
      end
    end

    assert_includes out, "Admin user created"
    assert_includes out, "abc123def456-Admin1Dev!"
    assert_includes out, "generated"
    assert_not_includes out, "using provided credentials"
    assert_equal 1, admin.password_writes
    assert_equal 1, admin.confirm_calls
    assert_equal 1, admin.save_calls
    assert_equal "admin", admin.assigned_attributes[:username]
    assert_equal "admin", admin.assigned_attributes[:role]
  end

  test "outside development a new admin reports the configured credentials source" do
    admin = FakeAdminUser.new(new_record: true)
    env_vars = { "ADMIN_EMAIL" => "admin@example.com", "ADMIN_PASSWORD" => "super_secret" }

    out, = capture_io do
      Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new("production")) do
        ENV.stub(:[], ->(key) { env_vars[key] }) do
          User.stub(:find_or_initialize_by, ->(*_args, **_kwargs) { admin }) do
            run_seed
          end
        end
      end
    end

    assert_includes out, "Admin user created"
    assert_includes out, "using provided credentials"
    assert_not_includes out, "super_secret"
    assert_not_includes out, "generated"
    assert_equal 1, admin.password_writes
    assert_equal 1, admin.confirm_calls
    assert_equal 1, admin.save_calls
  end

  test "outside development an existing admin is not rewritten on repeated seed runs" do
    admin = FakeAdminUser.new(new_record: false)
    env_vars = { "ADMIN_EMAIL" => "admin@example.com", "ADMIN_PASSWORD" => "super_secret" }

    out, = capture_io do
      Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new("production")) do
        ENV.stub(:[], ->(key) { env_vars[key] }) do
          User.stub(:find_or_initialize_by, ->(*_args, **_kwargs) { admin }) do
            run_seed
          end
        end
      end
    end

    assert_includes out, "Admin user already exists; credentials left unchanged."
    assert_not_includes out, "super_secret"
    assert_equal 0, admin.password_writes
    assert_equal 0, admin.confirm_calls
    assert_equal 0, admin.save_calls
    assert_empty admin.assigned_attributes
  end
end
