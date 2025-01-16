# Assume you have a JWT token to verify
token = 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM3MTEyOTk5LCJleHAiOjE3MzcxMTY1OTksImp0aSI6Ijk5NDc0ODAwLTM0YmUtNGU3Yi04YTVkLTRjMjNlMTRkMjY3YSJ9.fPb2mQ5OeFJzZQ3pcITbjl1nrPY74Y5c0NdR_S0pDJc'

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
