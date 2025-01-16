user = User.first
# test token generation
token, payload = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil)

# create an env object
env = Rack::MockRequest.env_for('/users', {
  'REQUEST_METHOD' => 'POST'
})

# options for token generation
opts = { scope: :user }

# mock auth object
class AuthMock
  attr_reader :env

  def initialize(env)
    @env = env
  end
end

# create an instance of AuthMock
auth = AuthMock.new(env)

# create an instance of Hooks
hooks = Warden::JWTAuth::Hooks.new

# call the prepare_token method
new_token = hooks.send(:prepare_token, user, auth, opts)

puts "New token: #{new_token}"
puts "token info: #{user.token_info}"


# --------------------------------------------------

# decode token
def decode_token(token_string)
  begin
    payload = Warden::JWTAuth::TokenDecoder.new.call token_string
  rescue => e
    config = [ Warden::JWTAuth.config.secret, false ]
    payload = JWT.decode(token_string, *config, {
      algorithm: Warden::JWTAuth.config.algorithm,
      verify_jti: true
    })
  end
end

puts "Decoded token 1: #{decode_token(token)}"
puts "Decoded token 2: #{decode_token(new_token)}"
