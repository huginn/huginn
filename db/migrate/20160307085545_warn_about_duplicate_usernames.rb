class WarnAboutDuplicateUsernames < ActiveRecord::Migration
  def up
    names = User.group('LOWER(username)').having('count(*) > 1').pluck('LOWER(username)')
    if names.length > 0
      puts "-----------------------------------------------------"
      puts "--------------------- WARNiNG -----------------------"
      puts "-------- Found users with duplicate usernames -------"
      puts "-----------------------------------------------------"
      puts "For the users to log in using their username they have to change it to a unique name"
      names.each do |name|
        puts
        puts "'#{name}' is used multiple times:"
        User.where(['LOWER(username) = ?', name]).each do |u|
          puts "#{u.id}\t#{u.email}"
        end
      end
      puts
      puts
    end
  end
end
