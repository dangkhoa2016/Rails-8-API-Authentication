namespace :jwt_denylist do
  desc "Delete expired JWT denylist records"
  task cleanup: :environment do
    removed = JwtDenylist.delete_expired!
    puts "Deleted #{removed} expired JWT denylist records"
  end
end
