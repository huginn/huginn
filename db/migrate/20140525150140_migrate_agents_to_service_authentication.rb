class MigrateAgentsToServiceAuthentication < ActiveRecord::Migration[4.2]
  def twitter_consumer_key(agent)
    agent.options['consumer_key'].presence || agent.credential('twitter_consumer_key')
  end

  def twitter_consumer_secret(agent)
    agent.options['consumer_secret'].presence || agent.credential('twitter_consumer_secret')
  end

  def twitter_oauth_token(agent)
    agent.options['oauth_token'].presence || agent.options['access_key'].presence || agent.credential('twitter_oauth_token')
  end

  def twitter_oauth_token_secret(agent)
    agent.options['oauth_token_secret'].presence || agent.options['access_secret'].presence || agent.credential('twitter_oauth_token_secret')
  end

  def up
    agents = Agent.where(type: ['Agents::TwitterUserAgent', 'Agents::TwitterStreamAgent', 'Agents::TwitterPublishAgent']).each do |agent|
      service = agent.user.services.create!(
        provider: 'twitter',
        name: "Migrated '#{agent.name}'",
        token: twitter_oauth_token(agent),
        secret: twitter_oauth_token_secret(agent)
      )
      agent.service_id = service.id
      agent.save!(validate: false)
    end
    migrated = false
    if agents.length > 0
      puts <<-EOF.strip_heredoc

        Your Twitter agents were successfully migrated. You need to update your .env file and add the following two lines:

        TWITTER_OAUTH_KEY=#{twitter_consumer_key(agents.first)}
        TWITTER_OAUTH_SECRET=#{twitter_consumer_secret(agents.first)}

        To authenticate new accounts with your twitter OAuth application you need to log in the to twitter application management page (https://apps.twitter.com/)
        and set the callback URL of your application to "http#{ENV['FORCE_SSL'] == 'true' ? 's' : ''}://#{ENV['DOMAIN']}/auth/twitter/callback"

      EOF
      migrated = true
    end
    if Agent.where(type: ['Agents::BasecampAgent']).count > 0
      puts <<-EOF.strip_heredoc

        Your Basecamp agents can not be migrated automatically. You need to manually register an application with 37signals and authenticate Huginn to use it.
        Have a look at the wiki (https://github.com/huginn/huginn/wiki/Configuring-OAuth-applications) if you need help.


      EOF
      migrated = true
    end
    sleep 20 if migrated
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Cannot revert migration to OAuth services"
  end
end

