# frozen_string_literal: true

# TODO: Remove this monkey-patch after upgrading to Devise 5.1+
# Devise-JWT calls trackable callbacks on every authenticated request,
# which pollutes the sign-in tracking columns when using JWT tokens.
# This patch skips trackable metadata for JWT-authenticated users.
module Devise
  module JWT
    module WardenStrategy
      def authenticate!
        super
        env["devise.skip_trackable".freeze] = true if self.valid?
      end
    end
  end
end

Warden::JWTAuth::Strategy.prepend Devise::JWT::WardenStrategy
