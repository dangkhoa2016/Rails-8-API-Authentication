class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :omniauthable
  # note: :timeoutable will not work with Rails sessions disabled
  devise :database_authenticatable, :registerable,
         :confirmable, :lockable, :trackable,
         :rememberable, :validatable, :recoverable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist

  attr_accessor :token_info
  enum :role, { user: "user", admin: "admin" }

  def on_jwt_dispatch(token, payload)
    # puts "on_jwt_dispatch: #{token}, #{payload}"
    self.token_info = { token: token, payload: payload }
  end

  def serializable_hash(options = nil)
    result = super

    if unconfirmed_email.present?
      result[:unconfirmed_email] = unconfirmed_email
    end

    result
  end

  def send_confirmation_instructions
    super
  rescue StandardError => e
    puts "Error sending confirmation instructions: #{e}"
  end
end
