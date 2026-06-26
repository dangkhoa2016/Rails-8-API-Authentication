# frozen_string_literal: true

# Monkey-patch to skip trackable metadata for JWT-authenticated users.
# Devise-JWT calls trackable callbacks on every authenticated request,
# which pollutes sign-in tracking columns when using JWT tokens.
#
# TODO: Remove this patch after upgrading to devise-jwt 0.14+
# (or when upstream ships a skip_trackable option).
jwt_version = Gem::Specification.find_by_name("devise-jwt").version
if jwt_version < Gem::Version.new("0.14")
  module Devise
    module JWT
      module WardenStrategy
        def authenticate!
          super
          env["devise.skip_trackable"] = true if valid?
        end
      end
    end
  end

  Warden::JWTAuth::Strategy.prepend Devise::JWT::WardenStrategy
end
