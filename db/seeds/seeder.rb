class Seeder
  def self.seed
    user = User.find_or_initialize_by(:email => ENV['SEED_EMAIL'] || "admin@example.com")
    if user.persisted?
      puts "User with email '#{user.email}' already exists, not seeding."
      exit
    end

    user.username = ENV['SEED_USERNAME'] || "admin"
    user.password = ENV['SEED_PASSWORD'] || "password"
    user.password_confirmation = ENV['SEED_PASSWORD'] || "password"
    user.invitation_code = User::INVITATION_CODES.first
    user.admin = true
    user.save!

    if DefaultScenarioImporter.seed(user)
      puts "NOTE: The example 'SF Weather Agent' will not work until you edit it and put in a free API key from http://www.wunderground.com/weather/api/"
      puts "See the Huginn Wiki for more Agent examples!  https://github.com/cantino/huginn/wiki"
    else
      raise('Unable to import the default scenario')
    end
  end
end
