# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

def get_email
  return 'admin@admin.admin' if Rails.env.development?

  if ENV['ADMIN_EMAIL'].present?
    puts "Loaded admin email from environment variables"
    ENV['ADMIN_EMAIL']
  elsif Rails.application.credentials.admin_email.present?
    puts "Loaded admin email from config/credentials.yml.enc"
    Rails.application.credentials.admin_email
  end
end

def get_password
  return 'adminadmin' if Rails.env.development?

  if ENV['ADMIN_PASSWORD'].present?
    puts "Loaded admin password from environment variables"
    ENV['ADMIN_PASSWORD']
  elsif Rails.application.credentials.admin_password.present?
    puts "Loaded admin password from config/credentials.yml.enc"
    Rails.application.credentials.admin_password
  end
end

email = get_email
password = get_password

if email && password
  user = User.find_or_create_by(
    email: email,
    username: 'admin',
    first_name: 'Admin',
    last_name: 'Master',
    role: 'admin'
  )

  user.password = password
  user.confirm
  user.save!

  puts "Admin user created at #{Time.now} using provided credentials in environment variables or config/credentials.yml.enc."
else
  puts %Q(
    Can't create admin user.
    Please provide either the ADMIN_EMAIL environment variable or config/credentials.yml.enc with :admin_email,
    and either the ADMIN_PASSWORD environment variable or config/credentials.yml.enc with :admin_password.
  )
end
