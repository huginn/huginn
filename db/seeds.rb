# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).

user = User.find_or_initialize_by_email("admin@example.com")
user.username = "admin"
user.password = "password"
user.password_confirmation = "password"
user.invitation_code = User::INVITATION_CODES.first
user.admin = true
user.save!

puts
puts

unless user.agents.where(:name => "SF Weather Agent").exists?
  Agent.build_for_type("Agents::WeatherAgent", user,
                       :name => "SF Weather Agent",
                       :schedule => "10pm",
                       :options => { 'location' => "94103", 'api_key' => "put-your-key-here" }).save!

  puts "NOTE: The example 'SF Weather Agent' will not work until you edit it and put in a free API key from http://www.wunderground.com/weather/api/"
end

unless user.agents.where(:name => "XKCD Source").exists?
  Agent.build_for_type("Agents::WebsiteAgent", user,
                       :name => "XKCD Source",
                       :schedule => "every_1d",
                       :type => "html",
                       :options => {
                           'url' => "http://xkcd.com",
                           'mode' => "on_change",
                           'expected_update_period_in_days' => 5,
                           'extract' => {
                               'url' => { 'css' => "#comic img", 'attr' => "src" },
                               'title' => { 'css' => "#comic img", 'attr' => "alt" },
                               'hovertext' => { 'css' => "#comic img", 'attr' => "title" }
                           }
                       }).save!
end

unless user.agents.where(:name => "iTunes Trailer Source").exists?
  Agent.build_for_type("Agents::WebsiteAgent", user, :name => "iTunes Trailer Source",
                       :schedule => "every_1d",
                       :options => {
                           'url' => "http://trailers.apple.com/trailers/home/rss/newtrailers.rss",
                           'mode' => "on_change",
                           'type' => "xml",
                           'expected_update_period_in_days' => 5,
                           'extract' => {
                               'title' => { 'css' => "item title", 'text' => true},
                               'url' => { 'css' => "item link", 'text' => true}
                           }
                       }).save!
end

unless user.agents.where(:name => "Rain Notifier").exists?
  Agent.build_for_type("Agents::TriggerAgent", user,
                       :name => "Rain Notifier",
                       :source_ids => user.agents.where(:name => "SF Weather Agent").pluck(:id),
                       :options => {
                           'expected_receive_period_in_days' => "2",
                           'rules' => [{
                                          'type' => "regex",
                                          'value' => "rain|storm",
                                          'path' => "conditions"
                                      }],
                           'message' => "Just so you know, it looks like '<conditions>' tomorrow in <location>"
                       }).save!
end

unless user.agents.where(:name => "Morning Digest").exists?
  Agent.build_for_type("Agents::DigestEmailAgent", user,
                       :name => "Morning Digest",
                       :schedule => "6am",
                       :options => { 'subject' => "Your Morning Digest", 'expected_receive_period_in_days' => "30" },
                       :source_ids => user.agents.where(:name => "Rain Notifier").pluck(:id)).save!
end

unless user.agents.where(:name => "Afternoon Digest").exists?
  Agent.build_for_type("Agents::DigestEmailAgent", user,
                       :name => "Afternoon Digest",
                       :schedule => "5pm",
                       :options => { 'subject' => "Your Afternoon Digest", 'expected_receive_period_in_days' => "7" },
                       :source_ids => user.agents.where(:name => ["iTunes Trailer Source", "XKCD Source"]).pluck(:id)).save!
end

puts "See the Huginn Wiki for more Agent examples!  https://github.com/cantino/huginn/wiki"
