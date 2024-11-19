class Seeder
  def self.seed
    if User.any?
      puts "At least one User already exists, not seeding."
      exit
    end

    user = User.find_or_initialize_by(:email => ENV['SEED_EMAIL'].presence || "admin@example.com")
    user.username = ENV['SEED_USERNAME'].presence || "admin"
    user.password = ENV['SEED_PASSWORD'].presence || "password"
    user.password_confirmation = ENV['SEED_PASSWORD'].presence || "password"
    user.invitation_code = User::INVITATION_CODES.first
    user.admin = true
    user.save!

    if DefaultScenarioImporter.seed(user)
      puts "In order to use the WeatherAgent you need an Weather Data API key from Pirate Weather https://pirate-weather.apiable.io/products/weather-data."
      puts "Sign up for one and then change the value of api_key: your-key in your seeded WeatherAgent."
      puts "See the Huginn Wiki for more Agent examples!  https://github.com/huginn/huginn/wiki"
    else
      raise('Unable to import the default scenario')
    end
  end
end
