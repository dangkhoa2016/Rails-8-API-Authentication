# Assume you have a JWT token to verify
token = ENV.fetch("TEST_JWT_TOKEN", "<your-jwt-token-here>")

# Create a mock request
env = Rack::MockRequest.env_for('/', {
  'HTTP_AUTHORIZATION' => "Bearer #{token}"
})

# Use the JWTAuth Strategy to verify the token
strategy = Warden::JWTAuth::Strategy.new(env, :user)

# Verify and authenticate the token
strategy.authenticate!

# Get the user from the JWT if authentication is successful
user = strategy.user
puts user.attributes
