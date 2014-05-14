class MigrateAgentsToServiceAuthentication < ActiveRecord::Migration
  def up
    agents = Agent.where(type: ['Agents::TwitterUserAgent', 'Agents::TwitterStreamAgent', 'Agents::TwitterPublishAgent']).each do |agent|
      service = agent.user.services.create!(
        provider: 'twitter',
        name: "Migrated '#{agent.name}'",
        token: agent.twitter_oauth_token,
        secret: agent.twitter_oauth_token_secret
      )
      agent.service_id = service.id
      agent.save!
    end
    if agents.length > 0
      puts <<-EOF.strip_heredoc

        Your Twitter agents were successfully migrated. You need to update your .env file and add the following two lines:

        TWITTER_OAUTH_KEY=#{agents.first.twitter_consumer_key}
        TWITTER_OAUTH_SECRET=#{agents.first.twitter_consumer_secret}


      EOF
    end
    if Agent.where(type: ['Agents::BasecampAgent']).count > 0
      puts <<-EOF.strip_heredoc

        Your Basecamp agents can not be migrated automatically. You need to manually register an application with 37signals and authenticate huginn to use it. 
        Have a look at the <Wiki TBD> if you need help.


      EOF
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Cannot revert migration to OAuth services"
  end
end

